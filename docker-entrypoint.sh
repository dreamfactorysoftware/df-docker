#!/bin/bash
set -e

# update site configuration
# if no servername is provided use dreamfactory.local as default
sed -i "s;%SERVERNAME%;${SERVERNAME:=dreamfactory.app};g" /etc/apache2/sites-available/dreamfactory.conf

# check if we have a linked database container
if [ -n "$DB_PORT_3306_TCP_ADDR" ]; then
  export DB_HOST=$DB_PORT_3306_TCP_ADDR
fi

(cd /opt/dreamfactory; grep -c "APP_KEY=SomeRandomString" .env > /dev/null && (echo "Generating APP_KEY"; php artisan key:generate))

#
# start Apache
exec /usr/sbin/apachectl -e info -DFOREGROUND
