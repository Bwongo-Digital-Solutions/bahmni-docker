# Crater PHP image override

This image wraps the existing `bahmni/crater-php:1.0.0-uganda1` image and fixes Laravel key handling.

## Why

The original startup script regenerates `APP_KEY` on every container start. Laravel uses this key to encrypt cookies and other application data, so changing it invalidates existing sessions.

## Configuration

Set `CRATER_APP_KEY` in the deployment's untracked `.env` file to a stable, installation-specific Laravel key. The Compose service passes it as `APP_KEY`; the image substitutes it into `/var/www/.env.template` and does not run `key:generate` during startup.

For an existing installation, preserve its current key when migrating:

```sh
docker exec <current-crater-php-container> sh -lc "grep '^APP_KEY=' /var/www/.env"
```

Copy that value into `CRATER_APP_KEY` in the host `.env` (do not commit it).

For a new installation, generate a unique key once with Laravel's `php artisan key:generate --show` in the Crater image, or generate a Laravel-compatible 32-byte base64 key, and store it in the host `.env`.

Do not change the key after the installation is initialized.
