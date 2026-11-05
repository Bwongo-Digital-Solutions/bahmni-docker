FROM bahmni/crater-php:1.0.0-uganda1

USER root
WORKDIR /var/www

# Never bake a shared/generated Laravel key into the image.
# Compose supplies the installation-specific CRATER_APP_KEY as APP_KEY.
RUN sed -i 's|^APP_KEY=.*$|APP_KEY=${APP_KEY}|' /var/www/.env.template

COPY start.sh /var/www/start.sh
RUN chmod 0755 /var/www/start.sh

CMD ["/var/www/start.sh"]
