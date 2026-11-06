# Crater authentication and persistent APP_KEY fix

**Project:** Bahmni Lite  
**Repository:** `Bwongo-Digital-Solutions/bahmni-docker`  
**Change branch:** `fix/crater-persistent-app-key`  
**Pull request:** [#1 – Fix Crater Laravel APP_KEY persistence](https://github.com/Bwongo-Digital-Solutions/bahmni-docker/pull/1)  
**Deployment URL used during troubleshooting:** `https://192.168.0.197:444`  
**Last verified:** 6 November 2026

## 1. Incident summary

Crater accepted the correct username and password but then reported that the user was unauthenticated or that the session had expired. The login page loaded, the login request redirected, but subsequent authenticated API requests sometimes returned HTTP 401.

The issue was investigated in the Bahmni Lite deployment at:

```text
/home/eron/CLINICEMR/bahmni-docker/bahmni-lite
```

The Crater services involved were:

- Compose service: `crater-php`
- Compose service: `crater-nginx`
- PHP container at the time: `bahmni-lite-crater-php-1`
- Original PHP image: `bahmni/crater-php:1.0.0-uganda1`

## 2. Root cause

The original Crater PHP container startup script performed these operations on every start:

```sh
envsubst < .env.template > .env.example
cp .env.example .env
php artisan key:generate --force
```

The unconditional `php artisan key:generate --force` generated a different Laravel `APP_KEY` each time the container started.

Laravel uses `APP_KEY` to encrypt and authenticate application data, including encrypted cookies. Changing it invalidates cookies encrypted using the previous key. This explains why a login could appear to work but existing browser sessions could become invalid after a container restart.

The investigation confirmed that the key in `/var/www/.env.template` differed from the key in the generated `/var/www/.env`. The session table itself was present and contained 15 records, so the immediate issue was not a missing database sessions table.

## 3. Other session configuration checked

The following settings were checked in the running container:

| Setting | Correct value |
|---|---|
| `SESSION_DRIVER` | `database` |
| `SESSION_DOMAIN` | Empty for this IP-based deployment |
| `SANCTUM_STATEFUL_DOMAINS` | `192.168.0.197:444` |
| `APP_URL` | `https://192.168.0.197:444` |

**Important:** `SANCTUM_STATEFUL_DOMAINS` must contain the host and port, not a URL scheme. Use `192.168.0.197:444`, not `https://192.168.0.197:444`.

For a deployment accessed by IP address, leaving `SESSION_DOMAIN` empty is appropriate. Access Crater consistently through the same origin, including port 444.

## 4. Emergency fix applied to the running installation

The immediate working installation was repaired without resetting the Crater database.

The running container was patched to:

1. Preserve its currently active Laravel APP_KEY in `/var/www/.env.template`.
2. Remove the unconditional `php artisan key:generate --force` line from `/var/www/start.sh`.
3. Save the patched container as a local image:
   `bahmni/crater-php:1.0.0-uganda1-sessionfix`.
4. Set the deployment's image tag to that local image.
5. Set the Sanctum stateful domain to `192.168.0.197:444`.
6. Recreate only the `crater-php` service, without running the normal installation/seeding path.

The two APP_KEY fingerprints were checked after recreation and matched. The runtime configuration reported:

```text
driver = database
domain = ""
sanctum_domains = ["192.168.0.197:444"]
```

This local `docker commit` was an emergency operational repair. It is not a reproducible source-build process by itself; the repository change described below is intended to replace that workaround for future builds.

## 5. Successful authentication verification

After the repair, the logs showed the following successful requests:

| Request | HTTP status | Meaning |
|---|---:|---|
| `GET /sanctum/csrf-cookie` | 204 | CSRF cookie endpoint responded |
| `POST /login` | 302 | Login redirected successfully |
| `GET /admin/dashboard` | 200 | Dashboard page loaded |
| `GET /api/v1/bootstrap` | 200 | Authenticated bootstrap API succeeded |
| `GET /api/v1/dashboard` | 200 | Dashboard API succeeded |

The PHP-FPM messages about the FPM `user` and `group` directives being ignored were notices, not the authentication failure.

At the time of this document, Crater login and dashboard access were working. Do not change the APP_KEY in the working installation.

## 6. Permanent repository change

A draft pull request was created:

[https://github.com/Bwongo-Digital-Solutions/bahmni-docker/pull/1](https://github.com/Bwongo-Digital-Solutions/bahmni-docker/pull/1)

Branch:

```text
fix/crater-persistent-app-key
```

The branch contains these changes:

- `bahmni-lite/crater-php/Dockerfile`: adds a wrapper image based on `bahmni/crater-php:1.0.0-uganda1`.
- `bahmni-lite/crater-php/start.sh`: writes the supplied stable APP_KEY into the generated Laravel environment and does not call `key:generate`.
- `bahmni-lite/crater-php/README.md`: documents migration and build instructions.
- `bahmni-lite/.env.local.example`: template for the installation-specific APP_KEY.
- `bahmni-lite/.gitignore`: excludes `.env.local` from Git.
- `bahmni-lite/docker-compose.yml`: builds the wrapper image and loads the local secret file.
- `bahmni-lite/.env`: updates the proposed image tag and leaves the session domain empty.

The pull request is intentionally still a **draft** until the new image build is tested. Do not merge or deploy it solely because the emergency local image works.

## 7. Safe procedure for the permanent build

### 7.1 Back up and preserve the current key

Before building or recreating Crater PHP, preserve the exact APP_KEY currently used by the working container. Do not generate a replacement key for an existing installation.

From the Bahmni Lite directory:

```sh
cd /home/eron/CLINICEMR/bahmni-docker/bahmni-lite

umask 077
docker exec bahmni-lite-crater-php-1 sh -lc \
  'grep "^APP_KEY=" /var/www/.env' > .env.local

# Confirm the key is present without displaying it.
grep -q '^APP_KEY=base64:' .env.local && echo "APP_KEY saved"
```

The `.env.local` file contains a secret. Keep it private and do not commit it, paste it into tickets, or include it in diagnostic output.

If `.env.local` already exists and contains the correct active key, do not overwrite it unnecessarily.

### 7.2 Check the deployment settings

The host `.env` file should use the correct deployment-specific values. For the current LAN address:

```dotenv
CRATER_APP_URL=https://192.168.0.197:444
CRATER_SANCTUM_STATEFUL_DOMAINS=192.168.0.197:444
CRATER_SESSION_DOMAIN=
```

The Compose service reads the stable Laravel key from the untracked `.env.local` file as `APP_KEY`.

### 7.3 Build and validate the proposed image

After checking out the pull-request branch and ensuring `.env.local` contains the current key:

```sh
docker compose config --quiet
docker compose build crater-php
```

Do not recreate the service until the build succeeds and the Compose configuration is correct.

Then recreate only the PHP service:

```sh
docker compose up -d --no-deps crater-php
```

This procedure does not ask Docker Compose to remove or reset the Crater database or uploaded-file volumes. Do not use `docker compose down -v`, volume deletion, database resets, or demo seeding as part of this fix.

### 7.4 Verify the running service

```sh
docker compose ps crater-php

docker exec bahmni-lite-crater-php-1 sh -lc '
cd /var/www
echo "===== APP KEY FINGERPRINTS ====="
grep "^APP_KEY=" .env.template | sha256sum
grep "^APP_KEY=" .env | sha256sum

echo
echo "===== SESSION CONFIGURATION ====="
php artisan tinker --execute="
dump([
  \"driver\" => config(\"session.driver\"),
  \"domain\" => config(\"session.domain\"),
  \"sanctum_domains\" => config(\"sanctum.stateful\")
]);
"
'
```

The two APP_KEY fingerprints must match. Never print or share the actual key.

Finally, test login and navigation in a private browser window using exactly:

```text
https://192.168.0.197:444
```

Expected successful log entries include login redirect (302), dashboard (200), bootstrap API (200), and dashboard API (200).

If authentication fails again, collect:

```sh
docker compose logs --since=5m crater-php crater-nginx
```

Also check the browser is using the same hostname/IP and port consistently.

## 8. Operational cautions

- **Never regenerate APP_KEY on a live installation.** Changing it can invalidate existing encrypted sessions and other encrypted application data.
- Keep one stable, unique APP_KEY per installation. Do not share the key between separate clinics or environments.
- Keep `.env.local` private and out of version control.
- Do not run migrations, seeders, or demo seeders merely to fix a login/session problem.
- Do not delete or recreate the Crater database or its volumes to resolve authentication.
- The `docker compose` warning that the top-level `version` attribute is obsolete is informational and unrelated to authentication.
- The local emergency image `1.0.0-uganda1-sessionfix` is distinct from the proposed source-built image. Keep the working deployment unchanged until the permanent build has been validated.
- The permanent image build and PR are not considered production-verified until the clean build and login test have both succeeded.

## 9. Current status at handover

- [x] Root cause identified: APP_KEY regenerated at every Crater PHP startup.
- [x] Database sessions table confirmed present.
- [x] Stable key preserved in the emergency local image.
- [x] Sanctum stateful domain corrected for the LAN URL.
- [x] Emergency Crater PHP container recreated and running.
- [x] Login, bootstrap, and dashboard API requests returned successful status codes.
- [x] Permanent source changes committed to `fix/crater-persistent-app-key`.
- [x] Draft pull request #1 opened.
- [ ] Clean build of the permanent repository image.
- [ ] Validate permanent image with the existing installation key.
- [ ] Mark PR ready and merge only after validation.

**Handover rule:** The existing working deployment takes priority. Preserve its current APP_KEY and data; test the permanent image on the same installation only after capturing the key and reviewing the Compose configuration.
