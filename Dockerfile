FROM dreamfactorysoftware/df-base-img:v7

# Configure Nginx
COPY dreamfactory.conf /etc/nginx/sites-available/dreamfactory.conf

# Get DreamFactory
ARG BRANCH=master
RUN git clone --branch $BRANCH https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory

WORKDIR /opt/dreamfactory

# Create storage structure and set permissions first
RUN mkdir -p /opt/dreamfactory/storage/app \
    && mkdir -p /opt/dreamfactory/storage/framework/cache \
    && mkdir -p /opt/dreamfactory/storage/framework/sessions \
    && mkdir -p /opt/dreamfactory/storage/framework/views \
    && mkdir -p /opt/dreamfactory/storage/logs \
    && mkdir -p /opt/dreamfactory/bootstrap/cache \
    && chown -R www-data:www-data /opt/dreamfactory/storage \
    && chown -R www-data:www-data /opt/dreamfactory/bootstrap/cache \
    && chmod -R 775 /opt/dreamfactory/storage \
    && chmod -R 775 /opt/dreamfactory/bootstrap/cache

# Add commercial files if running a licensed version
#COPY composer.* /opt/dreamfactory/

# Clear composer cache and install packages
RUN composer clear-cache && \
    COMPOSER_MEMORY_LIMIT=-1 composer install --no-dev --ignore-platform-reqs --no-scripts && \
    COMPOSER_MEMORY_LIMIT=-1 composer install --no-dev --ignore-platform-reqs && \
    php artisan df:env --db_connection=sqlite --df_install=Docker && \
    chown -R www-data:www-data /opt/dreamfactory && \
    rm /etc/nginx/sites-enabled/default

# Replace YOUR_LICENSE_KEY with your license key, keeping the comma at the end
#RUN sed -i "s,\#DF_REGISTER_CONTACT=,DF_LICENSE_KEY=YOUR_LICENSE_KEY," /opt/dreamfactory/.env

COPY docker-entrypoint.sh /docker-entrypoint.sh

# Set proper permission to docker-entrypoint.sh script and forward error logs to docker log collector
RUN chmod +x /docker-entrypoint.sh && ln -sf /dev/stderr /var/log/nginx/error.log

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 80

CMD ["/docker-entrypoint.sh"]