FROM bahmni/crater-php:1.0.0

COPY --chown=1000:1000 app/Models/Company.php /var/www/app/Models/Company.php

COPY --chown=1000:1000 database/seeders/CurrenciesTableSeeder.php /var/www/database/seeders/CurrenciesTableSeeder.php

# Force invoice and payment currency to the company currency.
COPY app/Http/Requests/InvoicesRequest.php /var/www/app/Http/Requests/InvoicesRequest.php
COPY app/Http/Requests/PaymentRequest.php /var/www/app/Http/Requests/PaymentRequest.php
