FROM ubuntu:xenial

MAINTAINER Arif Islam<arif@dreamfactory.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -y
RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:ondrej/php -y
RUN apt-get update && apt-get install -y --allow-unauthenticated\
    git-core curl nginx php7.1-fpm php7.1-common php7.1-cli php7.1-curl php7.1-json php7.1-mcrypt php7.1-mysqlnd php7.1-pgsql php7.1-sqlite \
    php-pear php7.1-dev php7.1-ldap php7.1-sybase php7.1-mbstring php7.1-zip php7.1-soap openssl pkg-config python nodejs python-pip zip ssmtp wget

RUN ln -s /usr/bin/nodejs /usr/bin/node

RUN pip install bunch

RUN pecl install mongodb && \
    echo "extension=mongodb.so" > /etc/php/7.1/mods-available/mongodb.ini && \
    phpenmod mongodb

RUN git clone https://github.com/dreamfactorysoftware/v8-compiled.git /v8
RUN mkdir /opt/v8
WORKDIR /v8
RUN cp -R ubuntu_16.04/PHP7.1/* /opt/v8
RUN git clone https://github.com/phpv8/v8js.git /v8js
WORKDIR /v8js
RUN phpize
RUN ./configure --with-v8js=/opt/v8
RUN make && make install
RUN echo "extension=v8js.so" > /etc/php/7.1/mods-available/v8js.ini
RUN phpenmod v8js
WORKDIR /
RUN rm -Rf v8 && rm -Rf v8js

# install php cassandra extension
RUN mkdir /cassandra
WORKDIR /cassandra
RUN apt-get install -y libgmp-dev libpcre3-dev g++ make cmake libssl-dev
RUN wget -q http://downloads.datastax.com/cpp-driver/ubuntu/16.04/dependenices/libuv/v1.8.0/libuv_1.8.0-1_amd64.deb && \
    wget -q http://downloads.datastax.com/cpp-driver/ubuntu/16.04/dependenices/libuv/v1.8.0/libuv-dev_1.8.0-1_amd64.deb && \
    wget -q http://downloads.datastax.com/cpp-driver/ubuntu/16.04/cassandra/v2.4.2/cassandra-cpp-driver_2.4.2-1_amd64.deb && \
    wget -q http://downloads.datastax.com/cpp-driver/ubuntu/16.04/cassandra/v2.4.2/cassandra-cpp-driver-dev_2.4.2-1_amd64.deb
RUN dpkg -i --force-overwrite libuv_1.8.0-1_amd64.deb
RUN dpkg -i libuv-dev_1.8.0-1_amd64.deb
RUN dpkg -i cassandra-cpp-driver_2.4.2-1_amd64.deb
RUN dpkg -i cassandra-cpp-driver-dev_2.4.2-1_amd64.deb
RUN git clone https://github.com/datastax/php-driver.git
WORKDIR /cassandra/php-driver
RUN git checkout tags/v1.2.1
WORKDIR /cassandra/php-driver/ext
RUN phpize
RUN ./configure
RUN make
RUN make install
RUN echo "extension=cassandra.so" > /etc/php/7.1/mods-available/cassandra.ini
RUN phpenmod cassandra
WORKDIR /
RUN rm -Rf cassandra

# install php couchbase extension
RUN mkdir /couchbase
WORKDIR /couchbase
RUN wget http://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-2-amd64.deb
RUN dpkg -i couchbase-release-1.0-2-amd64.deb
RUN apt-get update -y
RUN apt-get install -y --allow-unauthenticated libcouchbase-dev build-essential
RUN pecl install pcs-1.3.1
RUN pecl install couchbase
RUN echo "extension=pcs.so" > /etc/php/7.1/mods-available/pcs.ini
RUN echo "extension=couchbase.so" > /etc/php/7.1/mods-available/couchbase.ini
RUN phpenmod pcs && phpenmod couchbase
WORKDIR /
RUN rm -Rf couchbase

# configure sendmail
RUN echo 'sendmail_path = "/usr/sbin/ssmtp -t"' > /etc/php/7.1/cli/conf.d/mail.ini

RUN rm -rf /var/lib/apt/lists/*

# install composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer


# Configure Nginx/php-fpm
RUN rm /etc/nginx/sites-enabled/default
ADD dreamfactory.conf /etc/nginx/sites-available/dreamfactory.conf
RUN ln -s /etc/nginx/sites-available/dreamfactory.conf /etc/nginx/sites-enabled/dreamfactory.conf && \
    sed -i "s/pm.max_children = 5/pm.max_children = 5000/" /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i "s/pm.start_servers = 2/pm.start_servers = 150/" /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i "s/pm.min_spare_servers = 1/pm.min_spare_servers = 100/" /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i "s/pm.max_spare_servers = 3/pm.max_spare_servers = 200/" /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i "s/worker_connections 768;/worker_connections 2048;/" /etc/nginx/nginx.conf && \
    sed -i "s/keepalive_timeout 65;/keepalive_timeout 10;/" /etc/nginx/nginx.conf

# get app src
RUN git clone https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory

WORKDIR /opt/dreamfactory
RUN git checkout tags/2.4.1

# install packages
RUN composer install --no-dev

RUN php artisan dreamfactory:setup --no-app-key --db_driver=sqlite --df_install=Docker

# Comment out the line above and uncomment these this line if you're building a docker image for Bluemix.  If you're
# not using redis for your cache, change the value of --cache_driver to memcached or remove it for the standard
# file based cache.  If you're using a mysql service, change db_driver to mysql
#RUN php artisan dreamfactory:setup --no-app-key --db_driver=pgsql --cache_driver=redis --df_install="Docker(Bluemix)"

RUN chown -R www-data:www-data /opt/dreamfactory

ADD docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# forward request and error logs to docker log collector
RUN ln -sf /dev/stderr /var/log/nginx/error.log

# Uncomment this is you are building for Bluemix and will be using ElephantSQL
#ENV BM_USE_URI=true

EXPOSE 80

CMD ["/docker-entrypoint.sh"]
