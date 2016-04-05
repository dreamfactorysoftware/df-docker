#!/bin/bash
set -e

# update site configuration
# if no servername is provided use dreamfactory.local as default
sed -i "s;%SERVERNAME%;${SERVERNAME:=dreamfactory.app};g" /etc/apache2/sites-available/dreamfactory.conf

# check if we have a linked database container
if [ -n "$DB_PORT_3306_TCP_ADDR" ]; then
  export DB_HOST=$DB_PORT_3306_TCP_ADDR
fi

# generate AppKey on first run
cd /opt/dreamfactory
if [ ! -e .first_run_done ]; then
  echo "Generating APP_KEY"
  php artisan key:generate
  touch .first_run_done
fi

# Make sure we're not confused by old, incompletely-shutdown httpd
# context after restarting the container.  httpd won't start correctly
# if it thinks it is already running. Same path as APACHE_RUN_DIR in /etc/apache2/envvars
rm -rf /var/run/apache2/*

#
# start Apache
exec /usr/sbin/apachectl -e info -DFOREGROUND
