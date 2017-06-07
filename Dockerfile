FROM oraclelinux:7.2

MAINTAINER Arif Islam<arif@dreamfactory.com>

ARG GITHUB_TOKEN=''
ENV container docker

RUN yum update -y
RUN yum install -y git wget

RUN wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
RUN wget http://rpms.remirepo.net/enterprise/remi-release-7.rpm
RUN rpm -Uvh remi-release-7.rpm epel-release-latest-7.noarch.rpm
RUN yum-config-manager --enable remi-php71
RUN yum update -y
RUN yum install -y vim curl nginx php-fpm php-common php-xml php-devel php-pdo php-cli php-curl php-json php-mcrypt php-mysqlnd php-pgsql php-sqlite3 \
    php-pear curl-devel zlib-devel pcre-devel php-ldap php-interbase php-mbstring php-zip php-soap openssl-devel python nodejs python-pip zip re2c ssmtp gcc-c++ \
    gcc build-essentials composer pkgconfig

RUN ln -s /opt/remi/php71/root/bin/php /usr/local/bin/php

RUN curl https://packages.microsoft.com/config/rhel/7/prod.repo > /etc/yum.repos.d/mssql-release.repo
RUN yum update -y
RUN yum remove -y unixODBC-utf16-devel
RUN ACCEPT_EULA=Y yum install -y msodbcsql mssql-tools
RUN yum install -y unixODBC-devel
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
RUN /bin/bash -c "source ~/.bashrc"

RUN pip install bunch
RUN pecl install igbinary
RUN echo "extension=igbinary.so" > /etc/php.d/41-igbinary.ini

RUN pecl install mongodb
RUN echo "extension=mongodb.so" > /etc/php.d/41-mongodb.ini

RUN pecl install sqlsrv pdo_sqlsrv
RUN echo "extension=sqlsrv.so" > /etc/php.d/41-sqlsrv.ini
RUN echo "extension=pdo_sqlsrv.so" > /etc/php.d/41-pdo_sqlsrv.ini

ADD dreamfactory.conf /etc/nginx/conf.d/dreamfactory.conf
RUN sed -i "s/pm.max_children = 50/pm.max_children = 5000/" /etc/php-fpm.d/www.conf && \
    sed -i "s/pm.start_servers = 5/pm.start_servers = 150/" /etc/php-fpm.d/www.conf && \
    sed -i "s/pm.min_spare_servers = 5/pm.min_spare_servers = 100/" /etc/php-fpm.d/www.conf && \
    sed -i "s/pm.max_spare_servers = 35/pm.max_spare_servers = 200/" /etc/php-fpm.d/www.conf && \
    sed -i "s/user = apache/user = nginx/" /etc/php-fpm.d/www.conf && \
    sed -i "s/group = apache/group = nginx/" /etc/php-fpm.d/www.conf && \
    sed -i "s/worker_connections 1024;/worker_connections 2048;/" /etc/nginx/nginx.conf && \
    sed -i "s/keepalive_timeout 65;/keepalive_timeout 10;/" /etc/nginx/nginx.conf && \
    sed -i "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm\/php7.1-fpm.sock/" /etc/php-fpm.d/www.conf && \
    sed -i "s/listen       80 default_server;/listen       8088 default_server;/" /etc/nginx/nginx.conf && \
    sed -i "s/\[::\]:80/\[::\]:8088/" /etc/nginx/nginx.conf


RUN git config --global http.sslVerify false
RUN git clone https://github.com/dreamfactorysoftware/dreamfactory /opt/dreamfactory

WORKDIR /opt/dreamfactory

COPY composer.json composer.json
COPY composer.lock composer.lock

RUN composer config github-oauth.github.com $GITHUB_TOKEN
# install packages
RUN composer install --no-dev

# Run setup
RUN php artisan df:env --db_connection=sqlite --df_install=Docker

#RUN chown -R nginx:nginx /opt/dreamfactory
ADD docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# forward request and error logs to docker log collector
RUN ln -sf /dev/stderr /var/log/nginx/error.log


EXPOSE 80

CMD ["/docker-entrypoint.sh"]