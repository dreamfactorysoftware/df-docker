FROM debian:jessie

MAINTAINER Felix Glaeske<felix@psy-coding.com>

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

# install packages
RUN composer install --no-dev

RUN chown -R www-data /opt/dreamfactory

ADD docker-entrypoint.sh /docker-entrypoint.sh

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/apache2/access.log
RUN ln -sf /dev/stderr /var/log/apache2/error.log

EXPOSE 80

CMD ["/docker-entrypoint.sh"]
