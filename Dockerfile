#ARG BASE=cgr.dev/custom-images/request-306@sha256:6016b955a5679a5a35c7b11275056a13bc01ee644d4d0867aa3ff65d59de7e1d
ARG BASE=cgr.dev/dreamfactory.com/df-docker-base
FROM $BASE

# The base image runs as non-root, but we need root to chown things below
USER root

# Configure Nginx
COPY dreamfactory.conf /etc/nginx/sites-available/dreamfactory.conf
# Note that the configuration expects it here, so to make smallest amount
# of changes, copy it there.
COPY dreamfactory.conf /etc/nginx/sites-enabled/dreamfactory.conf
# Include the sites-available so that it's included in the nginx.conf
# TODO: Maybe create a nginx.conf as part of this repo and copy it in there
# rather than relying on upstream changes.
RUN sed -i '/include.*mime/a     include \/etc\/nginx\/sites-enabled\\/*.conf;' /etc/nginx/nginx.conf
# Put the directories where we expect them to be in the docker-entrypoint.sh
RUN mkdir -p /etc/php/8.1/fpm/pool.d && cp /etc/php/php-fpm.d/www.conf /etc/php/8.1/fpm/pool.d/www.conf
RUN cp /etc/php/php-fpm.d/www.conf /etc/php/8.1/fpm/pool.d/www.conf

RUN cp /etc/php/php-fpm.conf /etc/php/8.1/fpm/php-fpm.conf && sed -i -e 's@include=.*@include=/etc/php/8.1/fpm/pool.d/*.conf@' /etc/php/8.1/fpm/php-fpm.conf && sed -i -e 's@^listen = .*@listen = /var/run/php-fpm.sock@' /etc/php/8.1/fpm/pool.d/www.conf

# Get DreamFactory. Do we want the whole repo?
ARG BRANCH=master
RUN git clone --branch $BRANCH https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory

WORKDIR /opt/dreamfactory

# Uncomment lines 14 & 23 if you would like to upgrade your environment while replacing the License Key value with your issued Key and adding the license files to the df-docker directory.
# COPY composer.* /opt/dreamfactory/

# Install packages
RUN composer install --no-dev --ignore-platform-reqs && \
    php artisan df:env --db_connection=sqlite --df_install=Docker && \
    chown -R www-data:www-data /opt/dreamfactory

# Should (some of) these be run here? They currently get run
# in docker-entrypoint.sh
# php artisan migrate --seed
# php artisan cache:clear
# php artisan config:clear
# php artisan df:setup

COPY docker-entrypoint.sh /docker-entrypoint.sh

# RUN sed -i "s,\#DF_REGISTER_CONTACT=,DF_LICENSE_KEY=YOUR_LICENSE_KEY," /opt/dreamfactory/.env

# Set proper permission to docker-entrypoint.sh script and forward error logs to docker log collector
RUN mkdir -p /var/log/nginx && touch /var/log/nginx/error.log
RUN chmod +x /docker-entrypoint.sh && ln -sf /dev/stderr /var/log/nginx/error.log

# THIS IS BAD!!! Seems like `nobody` writes to some places. Maybe others???
# Wonder if this is because some things run as root and some as nginx, or ???
RUN chmod -R 777 /opt/dreamfactory/storage

# Clean up
RUN rm -rf /tmp/* /var/tmp/*

EXPOSE 80

ENTRYPOINT ["/bin/bash", "/docker-entrypoint.sh"]
#CMD ["/docker-entrypoint.sh"]
