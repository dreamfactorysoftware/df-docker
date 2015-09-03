# df-docker
Docker container for DreamFactory 2.0.

# Configuration method 1 (use docker-compose)
The easiest way to configure the DreamFactory application is to use docker-compose.

## Clone the df-docker repo
`cd ~/repos` (or wherever you want the clone of the repo to be)  
`git clone https://github.com/dreamfactorysoftware/df-docker.git`  
`cd df-docker`

## Edit `docker-compose.yml` (optional)

## Copy .env file to df-docker directory
The application looks for a `.env` file to read its configuration. You can find an example [here](https://github.com/dreamfactorysoftware/dreamfactory/blob/master/.env-dist)
Copy the file, adjust the settings to your needs and save as `.env`. When starting the container you have to add the file to the container using the option `-v /PATH_TO_ENV_FILE:/opt/dreamfactory/.env`.

## Build containers
`sudo docker-compose build`

## Start containers
`sudo docker-compose up -d`

## Add an entry to /etc/hosts
`127.0.0.1 dreamfactory.app`

## Access the app
Go to 127.0.0.1 in your browser. It will take some time the first time. You will be asked to create your first admin user.

# Configuration method 2 (build your own)
If you don't want to use docker-compose you can build the images yourself.

## Clone the df-docker repo
`cd ~/repos` (or wherever you want the clone of the repo to be)  
`git clone https://github.com/dreamfactorysoftware/df-docker.git`  
`cd df-docker`

## Copy .env file to df-docker directory
The application looks for a `.env` file to read its configuration. You can find an example [here](https://github.com/dreamfactorysoftware/dreamfactory/blob/master/.env-dist)
Copy the file, adjust the settings to your needs and save as `.env`. When starting the container you have to add the file to the container using the option `-v /PATH_TO_ENV_FILE:/opt/dreamfactory/.env`.

## Build containers
`docker build -t dreamfactory/v2 .`
*Ensure that the database container is also created*

## Parameters
You can also pass all the options via command line using the flag `-e`. 

# Link database container
If your database runs inside another container you can simply link it under the name `db`.

## Start containers with external MySQL server
`docker run -d -p 127.0.0.1:80:80 -v /PATH_TO_ENV_FILE:/opt/dreamfactory/.env dreamfactory/v2`

## Start containers with linked MySQL server
`docker run -d -p 127.0.0.1:80:80 -v /PATH_TO_ENV_FILE:/opt/dreamfactory/.env --link df-mysql:db dreamfactory/v2`

## Add an entry to /etc/hosts
127.0.0.1 dreamfactory.app

## Access the app
Go to 127.0.0.1 in your browser. It will take some time the first time. You will be asked to create your first admin user.



