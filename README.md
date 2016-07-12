# df-docker
Docker container for DreamFactory 2.2.x

# Prerequisites

## Get Docker
- See: [https://docs.docker.com/installation](https://docs.docker.com/installation)

### Get Docker Compose (optional)
- See [https://docs.docker.com/compose/install](https://docs.docker.com/compose/install)

# Configuration method 1 (use Docker Hub Image)

## 1) Clone the df-docker repo
`cd ~/repos` (or wherever you want the clone of the repo to be)  
`git clone https://github.com/dreamfactorysoftware/df-docker.git`  
`cd df-docker`

## 2) Pull DreamFactory image
`docker pull dreamfactorysoftware/df-docker`

## 3) Ensure that the database container is created and running
`docker run -d --name df-mysql -e "MYSQL_ROOT_PASSWORD=root" -e "MYSQL_DATABASE=dreamfactory" -e "MYSQL_USER=df_admin" -e "MYSQL_PASSWORD=df_admin" mysql`

## 4) Ensure that the redis container is created and running
`docker run -d --name df-redis redis`

## 5) Start the dreamfactorysoftware/df-docker container with linked MySQL and Redis server 
If your database and redis runs inside another container you can simply link it under the name `db` and `rd` respectively. 
  
`docker run -d --name df-web -p 127.0.0.1:80:80 -e "DB_HOST=db" -e "DB_USERNAME=df_admin" -e "DB_PASSWORD=df_admin" -e "DB_DATABASE=dreamfactory" -e "REDIS_HOST=rd" -e "REDIS_DATABASE=0" -e "REDIS_PORT=6379" --link df-mysql:db --link df-redis:rd dreamfactorysoftware/df-docker`

## 6) Add an entry to /etc/hosts
127.0.0.1 dreamfactory.app

## 7) Access the app
Go to 127.0.0.1 in your browser. It will take some time the first time. You will be asked to create your first admin user.

# Configuration method 2 (use docker-compose)
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

## 5) Add an entry to /etc/hosts
`127.0.0.1 dreamfactory.app`

## 6) Access the app
Go to 127.0.0.1 in your browser. It will take some time the first time. You will be asked to create your first admin user.

# Configuration method 3 (build your own)
If you don't want to use docker-compose you can build the images yourself.

## 1) Clone the df-docker repo
`cd ~/repos` (or wherever you want the clone of the repo to be)  
`git clone https://github.com/dreamfactorysoftware/df-docker.git`  
`cd df-docker`

## 2) Build dreamfactory/v2 image
`docker build -t dreamfactory/v2 .`  

## 3) Ensure that the database container is created and running
`docker run -d --name df-mysql -e "MYSQL_ROOT_PASSWORD=root" -e "MYSQL_DATABASE=dreamfactory" -e "MYSQL_USER=df_admin" -e "MYSQL_PASSWORD=df_admin" mysql`

## 4) Ensure that the redis container is created and running
`docker run -d --name df-redis redis`

## 5) Start the dreamfactorysoftware/df-docker container with linked MySQL and Redis server 
If your database and redis runs inside another container you can simply link it under the name `db` and `rd` respectively. 
  
`docker run -d --name df-web -p 127.0.0.1:80:80 -e "DB_HOST=db" -e "DB_USERNAME=df_admin" -e "DB_PASSWORD=df_admin" -e "DB_DATABASE=dreamfactory" -e "REDIS_HOST=rd" -e "REDIS_DATABASE=0" -e "REDIS_PORT=6379" --link df-mysql:db --link df-redis:rd dreamfactory/v2`

## 6) Add an entry to /etc/hosts
127.0.0.1 dreamfactory.app

## 7) Access the app
Go to 127.0.0.1 in your browser. It will take some time the first time. You will be asked to create your first admin user.

# Notes
- You may have to use `sudo` for Docker commands depending on your setup.
- By default, the container only sends apache error logs to STDOUT. If you also want to have dreamfactory.log, e.g. for forwarding via docker logging driver
you can set environment variable `LOG_TO_STDOUT=true`

# Configuration method 4 (build your own for IBM Bluemix)

## 1) Install the IBM Containers command line interface
IBM Bluemix has a complete set of instructions available at https://console.ng.bluemix.net/docs/containers/container_cli_ov.html#container_cli_cfic

## 2) Login to Bluemix
`cf login`

## 3) Login to Bluemix Containers
`cf ic login`

## 4) Clone the df-docker repo
`cd ~/repos` (or wherever you want the clone of the repo to be)  
`git clone https://github.com/dreamfactorysoftware/df-docker.git`  
`cd df-docker`

## 5) Edit the Dockerfile
In the Dockerfile, you will find comments indicating which lines need to be commented out and which ones need to be commented.

## 6) Build dreamfactory/v2 image
`cf ic build -t dreamfactory/v2 .`

Once the image has been built, the `cf ic` command will push the image to your private container repository on Bluemix.

# Starting the image on Bluemix

## 1) From the Dashboard, click on 'Start Containers'
## 2) Create a Postgres or MySQL service that you leave unbound
## 3) Create a Redis service that you leave unbound
## 4) Click on the v2 icon in the list of containers
## 5) On the container configuration page, give your container a name, such as 'DF2', select a size (2GB Memory minimum recommended)
## 6) Select an already existing Public IP address or choose the 'Request and Bind Public IP' option from the dropdown
## 7) Expand the Advanced Options and select the services from steps 2 and 3

# Notes
- Based on extensive testing, it has been found that on Bluemix, the container works best using the Redis Cloud and 
ElephantSQL services.  For the Redis Cloud service, select the 30MB or higher plan, and for Elephant SQL, select 
'Pretty Panda' or higher.  The 'Tiny Turtle' service plan is not sufficient.
- Extensive testing has shown that the free ClearDB MySQL Database service is not sufficient to run DreamFactory 2.0.
- The MySQL or Postgres service must support a minimum of 10 concurrent connections for the proper operation of 
DreamFactory 2.0.
- At this time, the PostgreSQL by Composer and Redis by Compose can not be bound to a container.  This is an issue with 
Bluemix.
- At this time, a `user-provided` external service can not be bound to a container at this time.  This
is an issue with Bluemix.
- If you use a service other than ElephantSQL, when starting the image, in step 7, you will have to add the environment 
variable `BM_DB_SERVICE_KEY` and set it to the value present in the VCAP_SERVICES environment variable provided to the container. 
Unfortunately, the only practical way to find this out is to create the container, bind the services and then open a 
shell on the container once it's running.  To do this, get the CONTAINER ID by running `cf ic ps` and then run 
`cf ic exec -it "CONTAINERID" bash`, replacing CONTAINERID with the CONTAINER ID gotten from the `cf ic ps` command. Once
you are at a command prompt, run `echo $VCAP_SERVICES` which will display something like 

    `{"rediscloud": [{"name": "df2-redis", "entity": {"service_instance_url": "https://api.ng.bluemix.net/v2/service_instances/3811bc12-d42c-4a4a-9255-d5c1d42b4849"}, "plan": "30mb", "credentials": {"password": "mINogWGFMpTJC9g0", "hostname": "pub-redis-13942.dal-05.1.sl.garantiadata.com", "port": "13942"}, "label": "rediscloud", "metadata": {"url": "https://api.ng.bluemix.net/v2/service_keys/b323438b-470e-4c7b-a877-a33268c27072"}}], "elephantsql": [{"name": "df2-db", "entity": {"service_instance_url": "https://api.ng.bluemix.net/v2/service_instances/677f57e1-a637-4022-8b50-730f4372091b"}, "plan": "panda", "credentials": {"uri": "postgres://mcfmjlcl:JeOGfJ7_q7kWih0v2rzPa1I6XDYHHLc3@jumbo.db.elephantsql.com:5432/mcfmjlcl", "max_conns": "20"}, "label": "elephantsql", "metadata": {"url": "https://api.ng.bluemix.net/v2/service_keys/985b6785-9cbd-4f6c-bdb8-21e56d1e9d5f"}}]}`

    In this particular example, the service keys are `rediscloud` and `elephantsql` which are the defaults.
- If you use a service other than Redis Cloud, when starting the image, in step 7, you will have to add the environment
variable `BM_REDIS_SERVICE_KEY` and set it to the value present in VCAP_SERVICES environment variable provided to the 
container.  See the previous entry on how to view the values in VCAP SERVICES.
