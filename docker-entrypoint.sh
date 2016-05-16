#!/bin/bash
set -e

# update site configuration
# if no servername is provided use dreamfactory.app as default
sed -i "s;%SERVERNAME%;${SERVERNAME:=dreamfactory.app};g" /etc/apache2/sites-available/dreamfactory.conf

# do we have configs for a Redis Cache ?
if [ -n "$REDIS_HOST" ]; then
  sed -i "s/REDIS_HOST=rd/REDIS_HOST=$REDIS_HOST/" .env
  sed -i "s/#REDIS_DATABASE=/REDIS_DATABASE=$REDIS_DATABASE/" .env
fi
if [ -n "$REDIS_PASSWORD" ]; then
  sed -i "s/#REDIS_PASSWORD=/REDIS_PASSWORD=$REDIS_PASSWORD/" .env
fi

# do we have configs for an external DB ?
if [ -n "$DB_HOST" ]; then
  sed -i "s/DB_HOST=localhost/DB_HOST=$DB_HOST/" .env
  sed -i "s/DB_USERNAME=df_admin/DB_USERNAME=$DB_USERNAME/" .env
  sed -i "s/DB_PASSWORD=df_admin/DB_PASSWORD=$DB_PASSWORD/" .env
  sed -i "s/DB_DATABASE=dreamfactory/DB_DATABASE=$DB_DATABASE/" .env
fi

# check if we have a linked database container
if [ -n "$DB_PORT_3306_TCP_ADDR" ]; then
  export DB_HOST=$DB_PORT_3306_TCP_ADDR
fi

# check if we have a linked redis container
if [ -n "$RD_PORT_6379_TCP_ADDR" ]; then
  export REDIS_HOST=$RD_PORT_6379_TCP_ADDR
fi

# do we have an existing APP_KEY we should reuse ?
if [ -n "$APP_KEY" ]; then
  sed -i "s/APP_KEY=SomeRandomString/APP_KEY=$APP_KEY/" .env
else
  # generate AppKey on first run
  if [ ! -e .first_run_done ]; then
    echo "Generating APP_KEY"
    php artisan key:generate
    touch .first_run_done
  fi
fi

# Make sure we're not confused by old, incompletely-shutdown httpd
# context after restarting the container.  httpd won't start correctly
# if it thinks it is already running. Same path as APACHE_RUN_DIR in /etc/apache2/envvars
rm -rf /var/run/apache2/*

#
# start Apache
exec /usr/sbin/apachectl -e info -DFOREGROUND
