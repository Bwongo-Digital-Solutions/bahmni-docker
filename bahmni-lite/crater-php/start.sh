#!/bin/sh
set -eu

cd /var/www

if [ -z "${APP_KEY:-}" ]; then
    echo "ERROR: CRATER_APP_KEY is required. Set one stable Laravel APP_KEY in the host .env."
    echo "Generate one with: php artisan key:generate --show"
    exit 1
fi

envsubst < .env.template > .env.example
cp .env.example .env

php artisan storage:link || true

if [ "${AUTO_INSTALL:-false}" = "true" ]; then
    ./wait-for.sh --timeout=300 "${DB_HOST}:${DB_PORT}"
    php artisan migrate --force
    php artisan db:seed --force
    php artisan db:seed --class=DemoSeeder --force
fi

exec php-fpm
