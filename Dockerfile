FROM dreamfactorysoftware/df-base-img:php7.2

# Configure Nginx/php-fpm
RUN rm /etc/nginx/sites-enabled/default
COPY dreamfactory.conf /etc/nginx/sites-available/dreamfactory.conf
RUN ln -s /etc/nginx/sites-available/dreamfactory.conf /etc/nginx/sites-enabled/dreamfactory.conf && \
    sed -i "s/pm.max_children = 5/pm.max_children = 5000/" /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i "s/pm.start_servers = 2/pm.start_servers = 150/" /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i "s/pm.min_spare_servers = 1/pm.min_spare_servers = 100/" /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i "s/pm.max_spare_servers = 3/pm.max_spare_servers = 200/" /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i "s/pm = dynamic/pm = ondemand/" /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i "s/worker_connections 768;/worker_connections 2048;/" /etc/nginx/nginx.conf && \
    sed -i "s/keepalive_timeout 65;/keepalive_timeout 10;/" /etc/nginx/nginx.conf

# Get DreamFactory
RUN git clone --branch master https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory

WORKDIR /opt/dreamfactory

# Install packages
RUN composer global require hirak/prestissimo && \
    composer install --no-dev --ignore-platform-reqs && \
    php artisan df:env --db_connection=sqlite --df_install=Docker && \
    chown -R www-data:www-data /opt/dreamfactory
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Set proper permission to docker-entrypoint.sh script and forward error logs to docker log collector
RUN chmod +x /docker-entrypoint.sh && ln -sf /dev/stderr /var/log/nginx/error.log && rm -rf /var/lib/apt/lists/*

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 80

CMD ["/docker-entrypoint.sh"]
