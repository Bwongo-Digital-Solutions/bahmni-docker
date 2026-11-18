# Crater Uganda PHP Overlay

This overlay customizes the Bahmni Crater PHP image for Uganda.

## Included changes

- Adds Ugandan Shilling (UGX) currency support.
- Uses UGX as the company currency.
- Forces invoices to use the company currency.
- Forces payments to use the company currency.
- Sets invoice and payment exchange rates to 1.

## Build

Run from the bahmni-lite directory:

    docker build --no-cache \
      -t bahmni/crater-php:1.0.0-uganda1 \
      -f crater-php-overlay/Dockerfile \
      crater-php-overlay

Configure the instance .env:

    CRATER_PHP_IMAGE_TAG=1.0.0-uganda1
    CRATER_DEFAULT_CURRENCY=UGX

Recreate the PHP service:

    docker compose up -d --no-deps --force-recreate crater-php
    docker compose exec crater-php php artisan config:clear

Ensure the Crater company currency is configured as UGX.
