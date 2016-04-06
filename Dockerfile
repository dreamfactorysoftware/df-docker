FROM ubuntu:latest

MAINTAINER David Weiner<davidweiner@dreamfactory.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y git-core curl apache2 php5 php5-common php5-cli php5-curl php5-json php5-mcrypt php5-mysql php5-pgsql php5-sqlite && \
    rm -rf /var/lib/apt/lists/*

# install composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

RUN echo "ServerName localhost" | tee /etc/apache2/conf-available/servername.conf && \
    a2enconf servername

RUN rm /etc/apache2/sites-enabled/000-default.conf

RUN php5enmod mcrypt

ADD dreamfactory.conf /etc/apache2/sites-available/dreamfactory.conf
RUN a2ensite dreamfactory

RUN a2enmod rewrite

# get app src
RUN git clone https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory

WORKDIR /opt/dreamfactory

# Uncomment this line if you're building for Bluemix and using redis for your cache
#RUN composer require "predis/predis:~1.0"

# install packages
RUN composer install

RUN php artisan dreamfactory:setup --no-app-key --db_driver=mysql --df_install=Docker

# Comment out the line above and uncomment these this line if you're building a docker image for Bluemix.  If you're
# not using redis for your cache, change the value of --cache_driver to memcached or remove it for the standard
# file based cache.  If you're using a mysql service, change db_driver to mysql
#RUN php artisan dreamfactory:setup --no-app-key --db_driver=pgsql --cache_driver=redis --df_install="Docker(Bluemix)"

# Uncomment this line and set your existing APP_KEY if you want to reuse existing DF database and configs
# You also have to make sure that docker-entrypoint.sh is NEVER generating a new key.
#RUN sed -i 's/APP_KEY=SomeRandomString/APP_KEY=foobar_baz/' .env

RUN chown -R www-data:www-data /opt/dreamfactory

ADD docker-entrypoint.sh /docker-entrypoint.sh

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/apache2/access.log
RUN ln -sf /dev/stderr /var/log/apache2/error.log

# Uncomment this is you are building for Bluemix and will be using ElephantSQL
#ENV BM_USE_URI=true

EXPOSE 80

CMD ["/docker-entrypoint.sh"]
