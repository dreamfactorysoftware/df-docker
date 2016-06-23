FROM ubuntu:xenial

MAINTAINER Arif Islam<arif@dreamfactory.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y \
    git-core curl apache2 libapache2-mod-php7.0 php7.0-common php7.0-cli php7.0-curl php7.0-json php7.0-mcrypt php7.0-mysqlnd php7.0-pgsql php7.0-sqlite \
    php-pear php7.0-dev php7.0-ldap php7.0-sybase php7.0-mbstring php7.0-zip php7.0-soap openssl pkg-config python nodejs python-pip zip

RUN rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/nodejs /usr/bin/node

RUN pip install bunch

RUN pecl install mongodb && \
    echo "extension=mongodb.so" > /etc/php/7.0/mods-available/mongodb.ini && \
    phpenmod mongodb

RUN mkdir -p /usr/lib /usr/include
ADD v8/usr/lib/libv8* /usr/lib/
ADD v8/usr/include /usr/include/
ADD v8/usr/lib/php/20151012/v8js.so /usr/lib/php/20151012/v8js.so
RUN echo "extension=v8js.so" > /etc/php/7.0/mods-available/v8js.ini && phpenmod v8js

# install composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

RUN echo "ServerName localhost" | tee /etc/apache2/conf-available/servername.conf && \
    a2enconf servername
RUN rm /etc/apache2/sites-enabled/000-default.conf
ADD dreamfactory.conf /etc/apache2/sites-available/dreamfactory.conf
RUN a2ensite dreamfactory
RUN a2enmod rewrite

# get app src
RUN git clone https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory

WORKDIR /opt/dreamfactory

# install packages
RUN composer install --no-dev

RUN php artisan dreamfactory:setup --no-app-key --db_driver=mysql --df_install=Docker

# Comment out the line above and uncomment these this line if you're building a docker image for Bluemix.  If you're
# not using redis for your cache, change the value of --cache_driver to memcached or remove it for the standard
# file based cache.  If you're using a mysql service, change db_driver to mysql
#RUN php artisan dreamfactory:setup --no-app-key --db_driver=pgsql --cache_driver=redis --df_install="Docker(Bluemix)"

RUN chown -R www-data:www-data /opt/dreamfactory

ADD docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# forward request and error logs to docker log collector
RUN ln -sf /dev/stderr /var/log/apache2/error.log

# Uncomment this is you are building for Bluemix and will be using ElephantSQL
#ENV BM_USE_URI=true

EXPOSE 80

CMD ["/docker-entrypoint.sh"]
