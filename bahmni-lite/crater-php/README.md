# Crater PHP image override

This image wraps the existing `bahmni/crater-php:1.0.0-uganda1` image and fixes Laravel key handling.

## Why

The original startup script regenerates `APP_KEY` on every container start. Laravel uses this key to encrypt cookies and other application data, so changing it invalidates existing sessions.

## Existing installation upgrade

1. Copy `.env.local.example` to `.env.local`.
2. Preserve the currently active key from the existing container:

   ```sh
   docker exec <current-crater-php-container> sh -lc "grep '^APP_KEY=' /var/www/.env"
   ```

3. Put that exact value in `.env.local` as `APP_KEY=...`. Do not commit `.env.local`.
4. Build and recreate only Crater PHP:

   ```sh
   docker compose build crater-php
   docker compose up -d --no-deps crater-php
   ```

The database and uploaded-file volumes are not changed. The existing key is passed into the generated Laravel `.env` on each start, and the startup script no longer calls `key:generate`.

## New installation

Generate a unique key once and save it in `.env.local`:

```sh
printf 'APP_KEY=base64:%s\\n' "$(openssl rand -base64 32 | tr -d '\\n')" > .env.local
```

Do not change the key after the installation is initialized.
