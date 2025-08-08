<h1 align="center">
    <a href="https://dreamfactory.com/"><img src="https://raw.githubusercontent.com/dreamfactorysoftware/dreamfactory/master/readme/vertical-logo-fullcolor.png" alt="DreamFactory" width="250" /></a>
</h1>

<p align="center">
    Docker container for DreamFactory 7.x using Ubuntu 24.04, PHP 8.3 and NGINX.
</p>

<p align="center">
    <a href="http://guide.dreamfactory.com/">Get Started Guide</a> ∙ <a href="https://genie.dreamfactory.com">Try Online</a> ∙ <a href="https://github.com/dreamfactorysoftware/dreamfactory/blob/master/CONTRIBUTING.md">Contribute</a> ∙ <a href="http://community.dreamfactory.com/">Community Support</a> ∙ <a href="https://wiki.dreamfactory.com">Docs</a>
</p>

<p align="center">
    <img alt="GitHub" src="https://img.shields.io/github/license/dreamfactorysoftware/dreamfactory.svg?style=plastic">
    <img alt="Docker Pulls" src="https://img.shields.io/docker/pulls/dreamfactorysoftware/df-docker.svg?style=plastic">
    <img alt="GitHub Release Date" src="https://img.shields.io/github/release-date/dreamfactorysoftware/dreamfactory.svg?style=plastic">
</p>

<p align="center">
    <a href="https://twitter.com/dfsoftwareinc?lang=en"><img alt="Twitter Follow" src="https://img.shields.io/twitter/follow/dfsoftwareinc.svg?style=social"></a>
</p>

## Table of Contents

* <a href="#prerequisites">Prerequisites</a>
* <a href="#installation">Installation</a>
* <a href="#licensed">DreamFactory Licensed Edition</a>
* <a href="#persistent">Persisting Data</a>
* <a href="#testing">Testing Data</a>
* <a href="#documentation">Documentation</a>
* <a href="#commercial">Commercial Licenses</a>
* <a href="#feedback">Feedback</a>

<a name="prerequisites"></a>

## Prerequisites

### Install Docker
- See: [https://docs.docker.com/installation](https://docs.docker.com/installation)

### Install Docker Compose
- See [https://docs.docker.com/compose/install](https://docs.docker.com/compose/install)

<a name="installation"></a>
## Installing the DreamFactory Docker Container
The easiest way to configure the DreamFactory application is to use docker-compose. This will automatically spin up 4 containers, the DreamFactory application, MySQL container for the system database, Redis container for caching, and a <a href="#testing">Postgres database</a> with over 100k records preconfigured for testing.

### 1) Clone the df-docker repo
`cd ~/repos` (or wherever you want the clone of the repo to be)
`git clone https://github.com/dreamfactorysoftware/df-docker.git`
`cd df-docker`

### 2) Edit `docker-compose.yml` (optional)

### 3) Build images
`docker compose build`

### 4) Start containers
`docker compose up -d`

    NOTE: volume df-storage:/opt/dreamfactory/storage is created to store all file based (apps, logs etc.) data from DreamFactory.
    This basically stores all data written by DreamFactory (at /opt/dreamfactory/storage location) in the df-storage volume. This
    way if you delete your DreamFactory container your data will persist as long as you don't delete the df-storage volume.

    to stop and remove all containers you can use the command

        docker compose down

    to stop and remove all containers including volumes use

        docker compose down -v

### 5) Access Admin UI
Go to `127.0.0.1` in your browser. It will take some time upon building, but you will be asked to create your first admin user.

<a name="licensed"></a>
## Running a Licensed Instance

### 1) Add the license files to the `df-docker` directory

### 2) Uncomment lines 25 and 36 of `Dockerfile`

### 3) Add the License Key to line 36 of `Dockerfile`

### 4) Build images
`docker compose build`

### 5) Start containers
`docker compose up -d`

### 6) Access the app
Go to `127.0.0.1` in your browser. It will take some time upon building, but you will be asked to create your first admin user.

<a name="persistent"></a>
## Persisting System Database Configs
After you have spun up your DreamFactory instance, take the APP_KEY value from the `.env` file in `/opt/dreamfactory`. This can be done with the following command:<br>
`docker-compose exec web cat .env | grep APP_KEY`

Set this value as the APP_KEY value in the docker-compose.yml file (line 28), encapsulating it in single quotes, to avoid receiving "The MAC is invalid" errors within your instance should you ever need to rebuild.

<a name="testing"></a>
## Use the Included PostgreSQL Database

We mount a Postgres container that contains over 100k records to test without connecting your own data sets. To generate a REST API for this database login to your DreamFactory instance and click the `Connect to Database` button on the home page. Choose PostgreSQL, then add an easily recalled namespace such as pgsql. You can enter anything you'd like into the description field. Click `Next` and enter the below connection details and then press the `Create & Test` button:

* Host: example_data
* Port: 5432
* Database Name: dellstore
* Username: postgres
* Password: root_pw

This will generate a fully documented and secure API from the Postgres container. To use this API you'll next need to create a role-based access control (RBAC) and API key. Head over to the documentation (see below) for instructions.

<a name="documentation"></a>
## Documentation

Learn more about DreamFactory's many features by reading our [Getting Started Guide](http://guide.dreamfactory.com/).
Additional platform documentation can be found on the [DreamFactory wiki](http://wiki.dreamfactory.com).

<a name="commercial"></a>
## Commercial Licenses

In need of official technical support? Desire access to REST API generators for SQL Server, Oracle, SOAP, or mobile
push notifications? Require API limiting and/or auditing? Schedule a demo [with our team](https://www.dreamfactory.com/demo/)!

<a name="feedback"></a>
## Feedback and Contributions

Feedback is welcome on our [forum](http://community.dreamfactory.com/) or in the form of pull requests and/or issues. Contributions should follow the strategy outlined in ["Contributing to a project"](http://help.github.com/articles/fork-a-repo#contributing-to-a-project).
