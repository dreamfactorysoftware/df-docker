# df-docker
Docker container for DreamFactory 2.0.

# Prerequisites

## Get Docker
- See: [https://docs.docker.com/installation](https://docs.docker.com/installation)

### Get Docker Compose (optional)
- See [https://docs.docker.com/compose/install](https://docs.docker.com/compose/install)

### Using MS SQL?
The Docker image we provide does not include PHP drivers for MS SQL. If you need this functionality add the following to the 'apt-get install' line in the Dockerfile and build yourself a new image using the steps below.

php5-sybase php5-odbc freetds-common

# Configuration method 1 (use Docker Hub Image)

## 1) Clone the df-docker repo
`cd ~/repos` (or wherever you want the clone of the repo to be)  
`git clone https://github.com/dreamfactorysoftware/df-docker.git`  
`cd df-docker`

## 2) Copy .env file to df-docker directory
The application looks for a `.env` file to read its configuration. You can find an example [here](https://github.com/dreamfactorysoftware/dreamfactory/blob/master/.env-dist)
Copy the file, adjust the settings to your needs and save as `.env`. When starting the container you have to add the file to the container using the option `-v /PATH_TO_ENV_FILE:/opt/dreamfactory/.env`.

## 3) Pull DreamFactory image
`docker pull dreamfactorysoftware/df-docker`

## 4) Ensure that the database container is created and running
`docker run -d --name df-mysql -e "MYSQL_ROOT_PASSWORD=root" -e "MYSQL_DATABASE=dreamfactory" -e "MYSQL_USER=df_admin" -e "MYSQL_PASSWORD=df_admin" mysql`

## 5) Start the dreamfactorysoftware/df-docker container with linked MySQL server or with external MySQL server  
If your database runs inside another container you can simply link it under the name `db`.  
  
`docker run -d -p 127.0.0.1:80:80 -v /PATH_TO_ENV_FILE:/opt/dreamfactory/.env --link df-mysql:db dreamfactorysoftware/df-docker`

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

## 3) Copy .env file to df-docker directory
The application looks for a `.env` file to read its configuration. You can find an example [here](https://github.com/dreamfactorysoftware/dreamfactory/blob/master/.env-dist)
Copy the file, adjust the settings to your needs and save as `.env`.

## 4) Build images
`docker-compose build`

## 5) Start containers
`docker-compose up -d`

## 6) Add an entry to /etc/hosts
`127.0.0.1 dreamfactory.app`

## 7) Access the app
Go to 127.0.0.1 in your browser. It will take some time the first time. You will be asked to create your first admin user.

# Configuration method 3 (build your own)
If you don't want to use docker-compose you can build the images yourself.

## 1) Clone the df-docker repo
`cd ~/repos` (or wherever you want the clone of the repo to be)  
`git clone https://github.com/dreamfactorysoftware/df-docker.git`  
`cd df-docker`

## 2) Copy .env file to df-docker directory
The application looks for a `.env` file to read its configuration. You can find an example [here](https://github.com/dreamfactorysoftware/dreamfactory/blob/master/.env-dist)
Copy the file, adjust the settings to your needs and save as `.env`. When starting the container you have to add the file to the container using the option `-v /PATH_TO_ENV_FILE:/opt/dreamfactory/.env`.

## 3) Build dreamfactory/v2 image
`docker build -t dreamfactory/v2 .`  

## 4) Ensure that the database container is created and running
`docker run -d --name df-mysql -e "MYSQL_ROOT_PASSWORD=root" -e "MYSQL_DATABASE=dreamfactory" -e "MYSQL_USER=df_admin" -e "MYSQL_PASSWORD=df_admin" mysql`

## 5) Start the dreamfactory/v2 container with linked MySQL server or with external MySQL server  
If your database runs inside another container you can simply link it under the name `db`.  
  
`docker run -d -p 127.0.0.1:80:80 -v /PATH_TO_ENV_FILE:/opt/dreamfactory/.env --link df-mysql:db dreamfactory/v2`  
  
or  
  
`docker run -d -p 127.0.0.1:80:80 -v /PATH_TO_ENV_FILE:/opt/dreamfactory/.env dreamfactory/v2`

## 6) Add an entry to /etc/hosts
127.0.0.1 dreamfactory.app

## 7) Access the app
Go to 127.0.0.1 in your browser. It will take some time the first time. You will be asked to create your first admin user.

# Notes
- PATH_TO_ENV_FILE must be an absolute path on your file system like `/home/todd/repos/df-docker/.env`.
- You may have to use `sudo` for Docker commands depending on your setup.



