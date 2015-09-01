# df-docker
Docker container for DreamFactory 2.0.

# Configuration
You can choose between the following ways to configure the application. Choose the one which works best for your setup.

## .env file
The application looks for a `.env` file to read its configuration. You can find an example [here](https://github.com/dreamfactorysoftware/dreamfactory/blob/master/.env-dist)
Copy the file, adjust the settings to your needs and save as `.env`. When starting the container you have to add the file to the container using the option `-v /PATH_TO_ENV_FILE:/opt/dreamfactory/.env`.

## Parameters
You can also pass all the options via command line using the flag `-e`. 

## Compose
- Edit `docker-compose.yml` if needed
- Add `.env` to directory
- Run `docker-compose build`
- Run `docker-compose up -d

# Link database container
If your database runs inside another container you can simply link it under the name `db`.

# Start container
## With external MySQL server
`docker run -it --rm -p 127.0.0.1:23000:80 -v /PATH_TO_ENV_FILE:/opt/dreamfactory/.env dreamfactorysoftware/v2`

## With linked MySQL server
`docker run -it --rm -p 127.0.0.1:23000:80 -v /PATH_TO_ENV_FILE:/opt/dreamfactory/.env --link df-mysql:db dreamfactorysoftware/v2`
