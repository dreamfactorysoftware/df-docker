# df-docker

Docker container for DreamFactory 2.x using Ubuntu 16.04, PHP 7.1 and NGINX. This container includes following PHP extensions.

    calendar            cassandra           Core
    couchbase           ctype               curl
    date                dom                 exif
    fileinfo            filter              ftp
    gettext             hash                iconv
    igbinary            interbase           json
    ldap                libxml              mbstring
    mcrypt              mongodb             mysqli
    mysqlnd             openssl             pcntl
    pcre                pcs                 PDO
    pdo_dblib           PDO_Firebird        pdo_mysql
    pdo_pgsql           pdo_sqlite          pdo_sqlsrv
    pgsql               Phar                posix
    readline            Reflection          session
    shmop               SimpleXML           soap
    sockets             SPL                 sqlite3
    sqlsrv              standard            sysvmsg
    sysvsem             sysvshm             tokenizer
    v8js                wddx                xml
    xmlreader           xmlwriter           xsl
    Zend OPcache        zip                 zlib

# Prerequisites

## Get Docker
- See: [https://docs.docker.com/installation](https://docs.docker.com/installation)

### Get Docker Compose (optional)
- See [https://docs.docker.com/compose/install](https://docs.docker.com/compose/install)

## Environment options
- See [this table](#environment-options-1)

# Configuration method 1a (use docker-compose)
The easiest way to configure the DreamFactory application is to use docker-compose.

## 1) Clone the df-docker repo
`cd ~/repos` (or wherever you want the clone of the repo to be)  
`git clone https://github.com/dreamfactorysoftware/df-docker.git`  
`cd df-docker`

## 2) Edit `docker-compose.yml` (optional)

## 3) Build images
`docker-compose build`

## 4) Start containers
`docker-compose up -d`

    NOTE: volume df-storage:/opt/dreamfactory/storage is created to store all file based (apps, logs etc.) data from DreamFactory.
    This basically stores all data written by DreamFactory (at /opt/dreamfactory/storage location) in the df-storage volume. This 
    way if you delete your DreamFactory container your data will persist as long as you don't delete the df-storage volume.
    
    to stop and remove all containers you can use the command 
    
        docker-compose down
    
    to stop and remove all containers including volumes use 
    
        docker-compose down -v
    
## 5) Add an entry to /etc/hosts
`127.0.0.1 dreamfactory.app`

## 6) Access the app
Go to 127.0.0.1 in your browser. It will take some time the first time. You will be asked to create your first admin user.

# Configuration method 1b (use docker-compose with load balancing)
The easiest way to configure the DreamFactory application is to use docker-compose.

## 1) Clone the df-docker repo
`cd ~/repos` (or wherever you want the clone of the repo to be)  
`git clone https://github.com/dreamfactorysoftware/df-docker.git`  
`cd df-docker`

## 2) Rename `docker-compose.yml-load-balance` to `docker-compose.yml`. Recommend backing up original `docker-compose.yml` first.

## 3) Build images
`docker-compose build`

## 4) Start containers
`docker-compose up -d`

    NOTE: volume df-storage:/opt/dreamfactory/storage is created to store all file based (apps, logs etc.) data from DreamFactory.
    This basically stores all data written by DreamFactory (at /opt/dreamfactory/storage location) in the df-storage volume. This 
    way if you delete your DreamFactory container your data will persist as long as you don't delete the df-storage volume.
    
    to stop and remove all containers you can use the command 
    
        docker-compose down
    
    to stop and remove all containers including volumes use 
    
        docker-compose down -v

This will create 4 containers. Mysql, Redis, DreamFactory, and Load Balancer container. 

## 5) Add an entry to /etc/hosts
`127.0.0.1 dreamfactory.app`

## 6) Access the app
Go to 127.0.0.1 in your browser. It will take some time the first time. You will be asked to create your first admin user.

## 7) Add additional web (DreamFactory) containers
`docker-compose scale web=3`

This will add two more DreamFactory container. Now the load balancer is going to balance load in a round-robin fashion among these three DreamFactory containers.

# Configuration method 2 (build your own)
If you don't want to use docker-compose you can build the images yourself.

## 1) Clone the df-docker repo
`cd ~/repos` (or wherever you want the clone of the repo to be)  
`git clone https://github.com/dreamfactorysoftware/df-docker.git`  
`cd df-docker`

## 2) Build dreamfactory/v2 image
`docker build -t dreamfactory .`  

## 3) Ensure that the database container is created and running
`docker run -d --name df-mysql -e "MYSQL_ROOT_PASSWORD=root" -e "MYSQL_DATABASE=dreamfactory" -e "MYSQL_USER=df_admin" -e "MYSQL_PASSWORD=df_admin" mysql`

## 4) Ensure that the redis container is created and running
`docker run -d --name df-redis redis`

## 5) Start the dreamfactorysoftware/df-docker container with linked MySQL and Redis server 
If your database and redis runs inside another container you can simply link it under the name `db` and `rd` respectively. 
  
`docker run -d --name df-web -p 80:80 -e "DB_DRIVER=mysql" -e "DB_HOST=db" -e "DB_USERNAME=df_admin" -e "DB_PASSWORD=df_admin" -e "DB_DATABASE=dreamfactory" -e "CACHE_DRIVER=redis" -e "CACHE_HOST=rd" -e "CACHE_DATABASE=0" -e "CACHE_PORT=6379" --link df-mysql:db --link df-redis:rd dreamfactory`

## 6) Add an entry to /etc/hosts
127.0.0.1 dreamfactory.app

## 7) Access the app
Go to 127.0.0.1 in your browser. It will take some time the first time. You will be asked to create your first admin user.

# Notes
- You may have to use `sudo` for Docker commands depending on your setup.
- By default, the container only sends nginx error logs to STDOUT. If you also want to have dreamfactory.log, e.g. for forwarding via docker logging driver
you can set environment variable `LOG_TO_STDOUT=true`

# Environment options

|Option|Description| required? |default
|------|-----------|---|---|
|SERVERNAME|Domain for DF|no|dreamfactory.app
|DB_DRIVER|Database Driver (mysql,pgsql,sqlsrv,sqlite)|no|mysql when any DB_HOST supplied. Otherwise sqlite
|DB_HOST|Database Host|no|localhost
|DB_USERNAME|Database User|no|df_admin
|DB_PASSWORD|Database Password|no|df_admin
|DB_DATABASE|Database Name|no|dreamfactory
|DB_PORT|Database Port|no|3306
|CACHE_DRIVER|Cache Driver (file, redis, memcached)|no|*uses file*
|CACHE_HOST|Cache Host|no|*uses file caching*
|CACHE_DATABASE|Redis DB|only if CACHE_DRIVER is set to redis
|CACHE_PORT|Redis/Memcached Port|no|6379
|CACHE_PASSWORD|Redis/Memcached Password|no|*none used*
|CACHE_USERNAME|Memcached username|only if CACHE_DRIVER is set to memcached
|CACHE_WEIGHT|Memcached weight|only if CACHE_DRIVER is set to memcached
|CACHE_PERSISTENT_ID|Memcached persistent_id|only if CACHE_DRIVER is set to memcached
|APP_KEY|Application Key|yes for immutability|*generates a key*
|JWT_TTL|Login Token TTL|no|60
|JWT_REFRESH_TTL|Login Token Refresh TTL|no|20160
|ALLOW_FOREVER_SESSIONS|Allow refresh forever|no|false
|LOG_TO_STDOUT|Forward log to STDOUT|no|*not forwarded*
|SSMTP_mailhub|MX for mailing|yes if DF should mail|*no mailing capabilities*
|SSMTP_XXXX|prefix options with SSMTP_|no|see the [man page](http://manpages.ubuntu.com/manpages/trusty/man5/ssmtp.conf.5.html)
|LICENSE|DreamFactory commercial license (silver, gold). Requires setting up container with volume. See below for details.|no
|ADMIN_EMAIL|First admin user email|no
|ADMIN_PASSWORD|First admin user password|no
|ADMIN_FIRST_NAME|Admin user first name|no
|ADMIN_LAST_NAME|Admin user last name|no

# Deploy container with DreamFactory commercial packages (silver / gold)

For this purpose we are assuming that you have already built your DreamFactory image named `dreamfactory` following instructions under the "Configuration method 2 (build your own)" section.

Start your MySQL container.

`docker run -d --name df-mysql -e "MYSQL_ROOT_PASSWORD=root" -e "MYSQL_DATABASE=dreamfactory" -e "MYSQL_USER=df_admin" -e "MYSQL_PASSWORD=df_admin" mysql`

Start your Redis container.

`docker run -d --name df-redis redis`

Now, in order for DreamFactory container to install the extra commercial packages after it starts up, you will need to provide the commercial license files to the container using docker volume.
To mount an external (host) directory inside docker container you can use the `-v` flag as part of the `docker run` command. For example: `-v /path/to/your/directory/on/host:/your/path/inside/container`.
For DreamFactory the container path for license file must be `/opt/dreamfactory/license`. In addition to setting the volume you will need to use the `LICENSE` environment option to indicate your license (silver/gold).

Here is an example command to start the DreamFactory container with gold license. Assuming your license files (provided by your sales agent) are stored in /Users/john/df-commercial.

`docker run -d --name df-web -p 80:80 -e "DB_DRIVER=mysql" -e "DB_HOST=db" -e "DB_USERNAME=df_admin" -e "DB_PASSWORD=df_admin" -e "DB_DATABASE=dreamfactory" -e "CACHE_DRIVER=redis" -e "CACHE_HOST=rd" -e "CACHE_DATABASE=0" -e "CACHE_PORT=6379" -e "LICENSE=gold" -v "/Users/john/df-commercial:/opt/dreamfactory/license" --link df-mysql:db --link df-redis:rd dreamfactory`

This will start up your DreamFactory container and install the commercial packages based on your license files. Give it few seconds to fully install all packages before you access your instance at 127.0.0.1 on your browser.