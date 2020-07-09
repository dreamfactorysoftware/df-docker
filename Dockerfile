FROM dreamfactorysoftware/df-base-img:php7.2

# Configure Nginx
COPY dreamfactory.conf /etc/nginx/sites-available/dreamfactory.conf

# Get DreamFactory
RUN git clone --branch 4.3.1 https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -y && apt-get install -y --no-install-recommends software-properties-common

RUN LANG=C.UTF-8 add-apt-repository ppa:ondrej/php -y && \
    apt-get update && apt-get install -y --no-install-recommends --allow-unauthenticated \
    bash git-core curl mcrypt nginx openssl python nodejs zip unzip ssmtp wget gcc make autoconf pkg-config libc-dev libmcrypt-dev \
    php-pear php7.2-dev php7.2-fpm php7.2-common php7.2-cli php7.2-curl php7.2-json php7.2-mysqlnd php7.2-pgsql \
    php7.2-ldap php7.2-interbase php7.2-mbstring php7.2-bcmath php7.2-zip php7.2-soap php7.2-sybase php7.2-xml php7.2-sqlite php7.2-gd && \
    pecl channel-update pecl.php.net

RUN apt-get install -y --allow-unauthenticated python-pip python3-pip

RUN apt-get update && \
    ln -s /usr/bin/nodejs /usr/bin/node && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get install -y --no-install-recommends apt-transport-https locales && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends mssql-tools unixodbc-dev && \
    pecl install sqlsrv pdo_sqlsrv && \
    echo "extension=sqlsrv.so" > /etc/php/7.2/mods-available/sqlsrv.ini && \
    echo "extension=pdo_sqlsrv.so" > /etc/php/7.2/mods-available/pdo_sqlsrv.ini && \
    phpenmod sqlsrv pdo_sqlsrv && \
    pip install bunch && pip3 install munch && \
    pecl install igbinary && \
    echo "extension=igbinary.so" > /etc/php/7.2/mods-available/igbinary.ini && \
    phpenmod igbinary && \
    pecl install mcrypt-1.0.2 && \
    echo "extension=mcrypt.so" > /etc/php/7.2/mods-available/mcrypt.ini && \
    phpenmod mcrypt && \
    pecl install mongodb && \
    echo "extension=mongodb.so" > /etc/php/7.2/mods-available/mongodb.ini && \
    phpenmod mongodb
WORKDIR /

# install php cassandra extension
RUN mkdir /cassandra
WORKDIR /cassandra
RUN apt-get install -y --no-install-recommends libgmp-dev libpcre3-dev g++ cmake libssl-dev && \
    wget -q http://downloads.datastax.com/cpp-driver/ubuntu/16.04/dependencies/libuv/v1.11.0/libuv_1.11.0-1_amd64.deb && \
    wget -q http://downloads.datastax.com/cpp-driver/ubuntu/16.04/dependencies/libuv/v1.11.0/libuv-dev_1.11.0-1_amd64.deb && \
    wget -q http://downloads.datastax.com/cpp-driver/ubuntu/16.04/cassandra/v2.6.0/cassandra-cpp-driver_2.6.0-1_amd64.deb && \
    wget -q http://downloads.datastax.com/cpp-driver/ubuntu/16.04/cassandra/v2.6.0/cassandra-cpp-driver-dev_2.6.0-1_amd64.deb && \
    dpkg -i --force-overwrite libuv_1.11.0-1_amd64.deb && \
    dpkg -i libuv-dev_1.11.0-1_amd64.deb && \
    dpkg -i cassandra-cpp-driver_2.6.0-1_amd64.deb && \
    dpkg -i cassandra-cpp-driver-dev_2.6.0-1_amd64.deb && \
    git clone https://github.com/datastax/php-driver.git
WORKDIR /cassandra/php-driver
RUN git checkout tags/v1.2.2
WORKDIR /cassandra/php-driver/ext
RUN phpize && \
    ./configure && \
    make && make install && \
    echo "extension=cassandra.so" > /etc/php/7.2/mods-available/cassandra.ini && \
    phpenmod cassandra
WORKDIR /
RUN rm -Rf cassandra

# install php couchbase extension
RUN mkdir /couchbase
WORKDIR /couchbase
RUN wget http://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-2-amd64.deb && \
    dpkg -i couchbase-release-1.0-2-amd64.deb && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends --allow-unauthenticated libcouchbase-dev build-essential zlib1g-dev && \
    pecl install pcs-1.3.3 && \
    pecl install couchbase && \
    echo "extension=pcs.so" > /etc/php/7.2/mods-available/pcs.ini && \
    echo "extension=couchbase.so" > /etc/php/7.2/mods-available/xcouchbase.ini && \
    phpenmod pcs && phpenmod xcouchbase
WORKDIR /
RUN rm -Rf couchbase

# configure sendmail
RUN echo 'sendmail_path = "/usr/sbin/ssmtp -t"' > /etc/php/7.2/cli/conf.d/mail.ini

# install composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

WORKDIR /opt/dreamfactory

# Uncomment lines 12 & 22 if you would like to upgrade your environment while replacing the License Key value with your issued Key and adding the license files to the df-docker directory.
# COPY composer.* /opt/dreamfactory/

# Install packages
RUN composer global require hirak/prestissimo && \
    composer install --no-dev --ignore-platform-reqs && \
    php artisan df:env --db_connection=sqlite --df_install=Docker && \
    chown -R www-data:www-data /opt/dreamfactory && \
    rm /etc/nginx/sites-enabled/default
COPY docker-entrypoint.sh /docker-entrypoint.sh

# RUN sed -i "s,\#DF_REGISTER_CONTACT=,DF_LICENSE_KEY=YOUR_LICENSE_KEY," /opt/dreamfactory/.env

# Set proper permission to docker-entrypoint.sh script and forward error logs to docker log collector
RUN chmod +x /docker-entrypoint.sh && ln -sf /dev/stderr /var/log/nginx/error.log && rm -rf /var/lib/apt/lists/*

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 80

CMD ["/docker-entrypoint.sh"]
