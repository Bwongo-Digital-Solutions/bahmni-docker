# Uganda clinic configuration on Bahmni Lite

This deployment consumes the implementation-specific image published by the
`Bwongo-Digital-Solutions/clinic-config` repository:

`ghcr.io/bwongo-digital-solutions/uganda-clinic-config:dev`

## Image publishing

The clinic-config pull request validates the configuration and builds the
container on pull requests. After that change is merged into `dev`, the
workflow publishes the `dev` tag and an immutable `sha-<commit>` tag to
GitHub Container Registry (GHCR).

The GHCR package must be set to **Public** in the GitHub organization package
settings if the clinic server will pull it without authentication. If it is
kept private, authenticate the Docker host to GHCR before starting Compose.

## Deploy

From this directory:

```bash
docker compose --env-file .env config --services
docker compose --env-file .env pull bahmni-config
docker compose --env-file .env up -d bahmni-config
docker compose --env-file .env logs --tail=100 bahmni-config
docker compose --env-file .env up -d
```

Start the config service before OpenMRS so the shared `bahmni-config` volume
is seeded before OpenMRS mounts it read-only. The config container copies the
image's configuration contents into the shared volume; it does not remove
existing files or delete database data.

After a new config image is published, pull and recreate the config service,
then restart OpenMRS so Initializer can process changed masterdata:

```bash
docker compose --env-file .env pull bahmni-config
docker compose --env-file .env up -d --force-recreate bahmni-config
docker compose --env-file .env restart openmrs
```

## Existing installations

Keep the existing Compose project name and named volumes when upgrading an
installation. Do not run `docker compose down -v`, remove `openmrsdbdata`,
or change `CONFIG_VOLUME` as part of this config-image switch. Back up the
OpenMRS database and configuration volume before applying masterdata changes.

The current Uganda address hierarchy remains non-destructive
(`<wipe>false</wipe>)) and uses the configured `addresshierarchy.csv`.
