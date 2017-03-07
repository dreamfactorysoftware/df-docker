#!/bin/bash
set -e

# mail setup
CONF=/etc/ssmtp/ssmtp.conf
rm -f $CONF

for E in $(env)
do
  if [ "$(echo $E | sed -e '/^SSMTP_/!d' )" ]
  then
    echo $E | sed -e 's/^SSMTP_//' >> $CONF
  fi
done

# update site configuration
# if no servername is provided use dreamfactory.app as default
sed -i "s;%SERVERNAME%;${SERVERNAME:=dreamfactory.app};g" /etc/nginx/sites-available/dreamfactory.conf

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
  sed -i "s/DB_CONNECTION=sqlite/DB_CONNECTION=mysql/" .env
  sed -i "s/DB_HOST=localhost/DB_HOST=$DB_HOST/" .env
  sed -i "s/DB_USERNAME=df_admin/DB_USERNAME=$DB_USERNAME/" .env
  sed -i "s/DB_PASSWORD=df_admin/DB_PASSWORD=$DB_PASSWORD/" .env
  sed -i "s/DB_DATABASE=dreamfactory/DB_DATABASE=$DB_DATABASE/" .env
fi

if [ -n "$DB_DRIVER" ]; then
  echo "Setting DB_DRIVER"
  sed -i "s/DB_CONNECTION=sqlite/DB_CONNECTION=$DB_DRIVER/" .env
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

if [ -n "$LICENSE" ] && [ -f "/opt/dreamfactory/license/$LICENSE/composer.lock" ]; then
    echo "Installing $LICENSE packages..."
    cp /opt/dreamfactory/license/"$LICENSE"/composer.* /opt/dreamfactory
    composer install --no-dev
fi

# do we have first user provided in evn?
if [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
    lastExitCode=1
    echo "Setting up database and creating first admin user"
    while [ "$lastExitCode" != 0 ] ; do
        if [ -n "$ADMIN_FIRST_NAME" ] && [ -n "$ADMIN_LAST_NAME" ]; then
            output=$(php artisan df:setup --admin_email $ADMIN_EMAIL --admin_password $ADMIN_PASSWORD --admin_first_name $ADMIN_FIRST_NAME --admin_last_name $ADMIN_LAST_NAME)
        else
            output=$(php artisan df:setup --admin_email $ADMIN_EMAIL --admin_password $ADMIN_PASSWORD)
        fi

        if [[ "$output" != *"SQLSTATE[HY000]"* ]]; then
            lastExitCode=0
        else
            echo "Database connection failed. Wait 5 seconds and retry..."
            sleep 5s
        fi
    done;

    echo "$output"

    # Do we have a package to import?
    if [ -n "$PACKAGE" ]; then
      echo "Importing package $PACKAGE"
      php artisan df:import-pkg $PACKAGE --delete
    fi
fi

chown -R www-data:www-data storage/
chown -R www-data:www-data bootstrap/cache/

# do we have configs for Session management ?
jwt_vars=("JWT_TTL" "JWT_REFRESH_TTL" "ALLOW_FOREVER_SESSIONS")
for var in "${jwt_vars[@]}"
do
  if [ -n "${!var}" ]; then
    echo "Setting DF_${var}"
    sed -i "s/##DF_${var}=.*/DF_${var}=${!var}/" .env
  fi
done

if [ -n "$LOG_TO_STDOUT" ]; then
  echo "Also writing dreamfactory.log messages to STDOUT"
  # we cannot ln the log to stdout like with nginx logs, so we continuously tail it
  tail --pid $$ -F /opt/dreamfactory/storage/logs/dreamfactory.log &
fi

# start php7.1-fpm
service php7.1-fpm start

# start nginx
exec /usr/sbin/nginx -g "daemon off;"
