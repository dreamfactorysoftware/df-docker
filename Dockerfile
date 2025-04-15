FROM dreamfactorysoftware/df-base-img:v7

# Update nginx to the latest version
# Install prerequisites for adding repository
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg2 \
    ca-certificates \
    lsb-release \
    debian-archive-keyring && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add Official Nginx Repository Key
RUN curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg

# Add the Nginx repository using the official Ubuntu format
# This determines the codename (e.g., jammy, focal) and writes the sources.list file
RUN UBUNTU_CODENAME=$(lsb_release -cs) && \
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu/ ${UBUNTU_CODENAME} nginx" > /etc/apt/sources.list.d/nginx.list

# Update lists again (now including nginx repo), remove old, install new version
RUN apt-get update && \
    apt-get remove -y nginx nginx-common nginx-core nginx-full && \
    # Install latest version
    apt-get install -y --no-install-recommends nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# add nginx to the www-data group so Nginx process has access to PHP-FPM process with Unix sockets
RUN adduser nginx www-data

# Configure Nginx
COPY dreamfactory.conf /etc/nginx/conf.d/dreamfactory.conf

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
    rm -f /etc/nginx/conf.d/default.conf

# Replace YOUR_LICENSE_KEY with your license key, keeping the comma at the end
#RUN sed -i "s,\#DF_REGISTER_CONTACT=,DF_LICENSE_KEY=YOUR_LICENSE_KEY," /opt/dreamfactory/.env

COPY docker-entrypoint.sh /docker-entrypoint.sh

# Set proper permission to docker-entrypoint.sh script and forward error logs to docker log collector
RUN chmod +x /docker-entrypoint.sh && ln -sf /dev/stderr /var/log/nginx/error.log

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 80

CMD ["/docker-entrypoint.sh"]
