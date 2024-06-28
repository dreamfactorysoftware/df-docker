ARG BASE=dreamfactorysoftware/df-base-img:v6
FROM $BASE

# Configure NGINX
COPY dreamfactory.conf /etc/nginx/sites-available/dreamfactory.conf

# Get DreamFactory
ARG BRANCH=DP-573
RUN git clone --branch $BRANCH https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory

WORKDIR /opt/dreamfactory

# Uncomment lines 14 & 51 if you would like to upgrade your environment while replacing the License Key value with your issued Key and adding the license files to the df-docker directory.
# COPY composer.* /opt/dreamfactory/

# Install packages

RUN cd /opt/dreamfactory && composer install --no-cache --no-dev --ignore-platform-reqs && \
    php artisan df:env --db_connection=sqlite --df_install=Docker && \
    chown -R www-data:www-data /opt/dreamfactory && \
    rm /etc/nginx/sites-enabled/default

COPY docker-entrypoint.sh /docker-entrypoint.sh

# RUN sed -i "s,\#DF_REGISTER_CONTACT=,DF_LICENSE_KEY=YOUR_LICENSE_KEY," /opt/dreamfactory/.env

# Set proper permission to docker-entrypoint.sh script and forward error logs to docker log collector
RUN chmod +x /docker-entrypoint.sh && ln -sf /dev/stderr /var/log/nginx/error.log && rm -rf /var/lib/apt/lists/*

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 80

CMD ["/docker-entrypoint.sh"]
