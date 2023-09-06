#!/bin/bash
set -e

# mail setup
CONF=/etc/ssmtp/ssmtp.conf
rm -f $CONF

# Check if the directory already exists.
if [ ! -d "$CONF" ]; then
  ### Take action if $DIR exists ###
  mkdir /etc/ssmtp
fi

# Filter the env variables for ssmtp configs and write them to the config file
env | awk -F'\n' '/^SSMTP_/ { print substr($1, 7) }' > "$CONF"

# Configure NGINX and www.conf
ln -s /etc/nginx/sites-available/dreamfactory.conf /etc/nginx/sites-enabled/dreamfactory.conf && \
sed -i "s/pm.max_children = 5/pm.max_children = 5000/" /etc/php/8.1/fpm/pool.d/www.conf && \
sed -i "s/pm.start_servers = 2/pm.start_servers = 150/" /etc/php/8.1/fpm/pool.d/www.conf && \
sed -i "s/pm.min_spare_servers = 1/pm.min_spare_servers = 100/" /etc/php/8.1/fpm/pool.d/www.conf && \
sed -i "s/pm.max_spare_servers = 3/pm.max_spare_servers = 200/" /etc/php/8.1/fpm/pool.d/www.conf && \
sed -i "s/pm = dynamic/pm = ondemand/" /etc/php/8.1/fpm/pool.d/www.conf && \
sed -i "s/worker_connections 768;/worker_connections 2048;/" /etc/nginx/nginx.conf && \
sed -i "s/keepalive_timeout 65;/keepalive_timeout 10;/" /etc/nginx/nginx.conf

# update site configuration
# if no servername is provided use dreamfactory.app as default
sed -i "s;%SERVERNAME%;${SERVERNAME:=dreamfactory.app};g" /etc/nginx/sites-available/dreamfactory.conf

# Allow Laravel to accept requests from top level reverse proxy if it is using HTTPS. "off" by default.
sed -i "s;%HTTPS_HEADER%;${HTTPS_HEADER:=off};g" /etc/nginx/sites-available/dreamfactory.conf

# do we have configs for a cache ?
if [ -n "$CACHE_DRIVER" ]; then
  echo "Setting CACHE_DRIVER, CACHE_HOST, CACHE_DATABASE"
  sed -i "s/#CACHE_HOST=/CACHE_HOST=$CACHE_HOST/" .env
  sed -i "s/#CACHE_DATABASE=2/CACHE_DATABASE=$CACHE_DATABASE/" .env
  sed -i "s/CACHE_DRIVER=file/CACHE_DRIVER=$CACHE_DRIVER/" .env
fi

if [ -n "$CACHE_PORT" ]; then
  echo "Setting CACHE_PORT"
  sed -i "s/#CACHE_PORT=/CACHE_PORT=$CACHE_PORT/" .env
fi

if [ -n "$CACHE_USERNAME" ]; then
  echo "Setting CACHE_USERNAME"
  sed -i "s/#CACHE_USERNAME=/CACHE_USERNAME=$CACHE_USERNAME/" .env
fi

if [ -n "$CACHE_WEIGHT" ]; then
  echo "Setting CACHE_WEIGHT"
  sed -i "s/#CACHE_WEIGHT=/CACHE_WEIGHT=$CACHE_WEIGHT/" .env
fi

if [ -n "$CACHE_PERSISTENT_ID" ]; then
  echo "Setting CACHE_PERSISTENT_ID"
  sed -i "s/#CACHE_PERSISTENT_ID=/CACHE_PERSISTENT_ID=$CACHE_PERSISTENT_ID/" .env
fi

if [ -n "$CACHE_PASSWORD" ]; then
  echo "Setting CACHE_PASSWORD"
  sed -i "s/#CACHE_PASSWORD=/CACHE_PASSWORD=$CACHE_PASSWORD/" .env
fi

# do we have configs for an external DB ?
if [ -n "$DB_DRIVER" ]; then
  echo "Setting DB_DRIVER, DB_HOST, DB_USERNAME, DB_PASSWORD, and DB_DATABASE"
  sed -i "s/DB_CONNECTION=sqlite/DB_CONNECTION=$DB_DRIVER/" .env
  sed -i "s/#DB_HOST=/DB_HOST=$DB_HOST/" .env
  sed -i "s/#DB_USERNAME=/DB_USERNAME=$DB_USERNAME/" .env
  sed -i "s/#DB_PASSWORD=/DB_PASSWORD=$DB_PASSWORD/" .env
  sed -i "s/#DB_DATABASE=/DB_DATABASE=$DB_DATABASE/" .env
fi

if [ -n "$DB_PORT" ] && [[ $DB_PORT != *":"* ]]; then
  echo "Setting DB_PORT"
  sed -i "s/#DB_PORT=/DB_PORT=$DB_PORT/" .env
fi

# do we have an existing APP_KEY we should reuse ?
if [ -n "$APP_KEY" ]; then
  echo "Setting APP_KEY=$APP_KEY from environment"
  sed -i "s#APP_KEY=.*#APP_KEY=$APP_KEY#" .env
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
    composer install --no-dev --ignore-platform-reqs
    php artisan migrate --seed
    php artisan cache:clear
    php artisan config:clear
fi

# do we have first user provided in env?
if [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ] && [ -n "$ADMIN_PHONE" ];  then
    lastExitCode=1
    echo "Setting up database and creating first admin user"
    while [ "$lastExitCode" != 0 ] ; do
        if [ -n "$ADMIN_FIRST_NAME" ] && [ -n "$ADMIN_LAST_NAME" ]; then
            output=$(php artisan df:setup --admin_email $ADMIN_EMAIL --admin_password $ADMIN_PASSWORD --admin_first_name $ADMIN_FIRST_NAME --admin_last_name $ADMIN_LAST_NAME --admin_phone $ADMIN_PHONE)
        else
            output=$(php artisan df:setup --admin_email $ADMIN_EMAIL --admin_password $ADMIN_PASSWORD --admin_phone $ADMIN_PHONE)
        fi

        if [[ "$output" != *"SQLSTATE[HY000]"* ]] && [[ "$output" != *"No suitable servers found"* ]]; then
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

if [ -n "$APP_LOG_LEVEL" ]; then
  echo "Setting APP_LOG_LEVEL"
  sed -i "s/#APP_LOG_LEVEL=warning/APP_LOG_LEVEL=$APP_LOG_LEVEL/" .env
fi

if [ -n "$SESSION_DRIVER" ]; then
  echo "" >> .env
  echo "SESSION_DRIVER=$SESSION_DRIVER" >> .env
fi

if [ -n "$REDIS_HOST" ]; then
  echo "REDIS_HOST=$REDIS_HOST" >> .env
fi

if [ -n "$REDIS_PORT" ]; then
  echo "REDIS_PORT=$REDIS_PORT" >> .env
fi

if [ -n "$EXTERNAL_IP" ]; then
  echo "Setting EXTERNAL_IP"
  sed -i "s/#EXTERNAL_IP=/EXTERNAL_IP=$EXTERNAL_IP/" .env
fi

logsdb_vars=("LOGSDB_HOST" "LOGSDB_PORT" "LOGSDB_DATABASE" "LOGSDB_USERNAME" "LOGSDB_PASSWORD" "LOGSDB_ENABLED")
for var in "${logsdb_vars[@]}"
do
  if [ -n "${!var}" ]; then
    echo "Setting ${var}"
    sed -i "s/#${var}=.*/${var}=${!var}/" .env
  fi
done

if [ -n "$DF_REGISTER_CONTACT" ]; then
  echo "Setting DF_REGISTER_CONTACT"
  sed -i "s/#DF_REGISTER_CONTACT=/DF_REGISTER_CONTACT=$DF_REGISTER_CONTACT/" .env
fi

if [ -n "$DF_LICENSE_KEY" ]; then
  echo "Setting DF_LICENSE_KEY"
  sed -i "s/#DF_LICENSE_KEY=/DF_LICENSE_KEY=$DF_LICENSE_KEY/" .env
fi

if [ -n "$SENDMAIL_DEFAULT_COMMAND" ]; then
  echo "Setting SENDMAIL_DEFAULT_COMMAND=$SENDMAIL_DEFAULT_COMMAND"
  sed -i "s/#SENDMAIL_DEFAULT_COMMAND=.*/SENDMAIL_DEFAULT_COMMAND=\"$(echo "$SENDMAIL_DEFAULT_COMMAND" | sed 's/\//\\\//g')\"/" .env
fi

# start php8.1-fpm
service php8.1-fpm start

# start cron service for df-scheduler
service cron start

# start nginx
exec /usr/sbin/nginx -g "daemon off;"
