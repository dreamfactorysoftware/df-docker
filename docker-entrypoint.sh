#!/bin/bash
set -e

# mail setup
CONF=/etc/ssmtp/ssmtp.conf
rm $CONF

for E in $(env)
do
  if [ "$(echo $E | sed -e '/^SSMTP_/!d' )" ]
  then
    echo $E | sed -e 's/^SSMTP_//' >> $CONF
  fi
done

# update site configuration
# if no servername is provided use dreamfactory.app as default
sed -i "s;%SERVERNAME%;${SERVERNAME:=dreamfactory.app};g" /etc/apache2/sites-available/dreamfactory.conf

# do we have configs for a Redis Cache ?
if [ -n "$REDIS_HOST" ]; then
  echo "Setting CACHE_DRIVER=redis, REDIS_HOST, and REDIS_DATABASE"
  sed -i "s/#REDIS_HOST=127.0.0.1/REDIS_HOST=$REDIS_HOST/" .env
  sed -i "s/#REDIS_DATABASE=/REDIS_DATABASE=$REDIS_DATABASE/" .env
  sed -i "s/CACHE_DRIVER=file/CACHE_DRIVER=redis/" .env
fi

if [ -n "$REDIS_PORT" ]; then
  echo "Setting REDIS_PORT"
  sed -i "s/#REDIS_PORT=6379/REDIS_PORT=$REDIS_PORT/" .env
fi

if [ -n "$REDIS_PASSWORD" ]; then
  echo "Setting REDIS_PASSWORD"
  sed -i "s/#REDIS_PASSWORD=/REDIS_PASSWORD=$REDIS_PASSWORD/" .env
fi

# do we have configs for an external DB ?
if [ -n "$DB_HOST" ]; then
  echo "Setting DB_HOST, DB_USERNAME, DB_PASSWORD, and DB_DATABASE"
  sed -i "s/DB_HOST=localhost/DB_HOST=$DB_HOST/" .env
  sed -i "s/DB_USERNAME=df_admin/DB_USERNAME=$DB_USERNAME/" .env
  sed -i "s/DB_PASSWORD=df_admin/DB_PASSWORD=$DB_PASSWORD/" .env
  sed -i "s/DB_DATABASE=dreamfactory/DB_DATABASE=$DB_DATABASE/" .env
fi

# do we have an existing APP_KEY we should reuse ?
if [ -n "$APP_KEY" ]; then
  echo "Setting APP_KEY=$APP_KEY from environment"
  sed -i "s/APP_KEY=SomeRandomString/APP_KEY=$APP_KEY/" .env
else
  # generate AppKey on first run
  if [ ! -e .first_run_done ]; then
    echo "Generating APP_KEY"
    php artisan key:generate
    touch .first_run_done
  fi
fi

# do we have configs for Session management ?
jwt_vars=("JWT_TTL" "JWT_REFRESH_TTL" "ALLOW_FOREVER_SESSIONS")
for var in "${jwt_vars[@]}"
do
  if [ -n "${!var}" ]; then
    echo "Setting DF_${var}"
    sed -i "s/##DF_${var}=.*/DF_${var}=${!var}/" .env
  fi
done

# Make sure we're not confused by old, incompletely-shutdown httpd
# context after restarting the container.  httpd won't start correctly
# if it thinks it is already running. Same path as APACHE_RUN_DIR in /etc/apache2/envvars
rm -rf /var/run/apache2/*

if [ -n "$LOG_TO_STDOUT" ]; then
  echo "Also writing dreamfactory.log messages to STDOUT"
  # we cannot ln the log to stdout like with apache logs, so we continuously tail it
  tail --pid $$ -F /opt/dreamfactory/storage/logs/dreamfactory.log &
fi

#
# start Apache
exec /usr/sbin/apachectl -e info -DFOREGROUND
