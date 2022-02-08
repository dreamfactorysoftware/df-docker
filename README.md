# df-docker

Docker container for DreamFactory 4.x using Ubuntu 16.04, PHP 7.4 and NGINX.

## Prerequisites

### Get Docker
- See: [https://docs.docker.com/installation](https://docs.docker.com/installation)

### Get Docker Compose
- See [https://docs.docker.com/compose/install](https://docs.docker.com/compose/install)

### Persisting MySQL Data
After you have spun up your DreamFactory instance, take the APP_KEY value from the `.env` file in `/opt/dreamfactory` and then set this value as the APP_KEY value in the docker-compose.yml file (line 19) to avoid receiving "The MAC is invalid" errors within your instance should you ever need to rebuild.
 

## Configuration method docker-compose
The easiest way to configure the DreamFactory application is to use docker-compose.

### 1) Clone the df-docker repo
`cd ~/repos` (or wherever you want the clone of the repo to be)  
`git clone https://github.com/dreamfactorysoftware/df-docker.git`  
`cd df-docker`

### 2) Edit `docker-compose.yml` (optional)

### 3) Build images
`docker-compose build`

### 4) Start containers
`docker-compose up -d`

    NOTE: volume df-storage:/opt/dreamfactory/storage is created to store all file based (apps, logs etc.) data from DreamFactory.
    This basically stores all data written by DreamFactory (at /opt/dreamfactory/storage location) in the df-storage volume. This 
    way if you delete your DreamFactory container your data will persist as long as you don't delete the df-storage volume.
    
    to stop and remove all containers you can use the command 
    
        docker-compose down
    
    to stop and remove all containers including volumes use 
    
        docker-compose down -v
    
### 5) Add an entry to /etc/hosts
`127.0.0.1 dreamfactory.app`

### 6) Access the app
Go to 127.0.0.1 in your browser. It will take some time the first time. You will be asked to create your first admin user.

## Running a licensed instance

### 1) Add the upgraded composer files to the df-docker directory

### 2) Uncomment lines 12 and 21 of `Dockerfile`

### 3) Add the License Key to line 21 of `Dockerfile`

### 4) Build images
`docker-compose build`

### 5) Start containers
`docker-compose up -d`

### 6) Add an entry to /etc/hosts
`127.0.0.1 dreamfactory.app`

### 7) Access the app
Go to 127.0.0.1 in your browser. It will take some time the first time. You will be asked to create your first admin user.
