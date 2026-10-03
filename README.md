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
* <a href="#environment">Environment Variables</a>
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

If TLS is terminated in front of the container (reverse proxy, load balancer, or CDN), uncomment `HTTPS_HEADER: "on"` in the `web` service environment so DreamFactory generates `https://` URLs — without it, OAuth discovery metadata and other absolute URLs come out as `http://`. The quotes are required, since a bare `on` is parsed as a YAML boolean.

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

<a name="environment"></a>
## Environment Variables

`docker-entrypoint.sh` copies these container environment variables into `/opt/dreamfactory/.env` on every start (php-fpm and cron do not see the container environment, so `.env` is the single source of truth). Unset variables leave the image defaults in place.

| Variable | Default | Purpose |
|----------|---------|---------|
| `SERVERNAME` | `dreamfactory.app` | nginx `server_name` |
| `HTTPS_HEADER` | `off` | set to `"on"` behind a TLS-terminating proxy so Laravel emits `https://` URLs |
| `APP_KEY` | generated on first start | Laravel encryption key. Pin it (see [Persisting System Database Configs](#persistent)) or encrypted service credentials break when the container is re-created |
| `DB_DRIVER` / `DB_CONNECTION` | `sqlite` | system database driver (`mysql`, `pgsql`, `sqlsrv`, `sqlite`) |
| `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` | – | system database connection. With `DB_DRIVER=sqlite`, `DB_DATABASE` may be an absolute path (put it under `/opt/dreamfactory/storage/` so it lives in the volume); the file is created if missing |
| `CACHE_DRIVER` | `file` | cache store, written to both `CACHE_DRIVER` (legacy) and `CACHE_STORE` (7.x) |
| `CACHE_HOST`, `CACHE_PORT`, `CACHE_DATABASE`, `CACHE_USERNAME`, `CACHE_PASSWORD`, `CACHE_WEIGHT`, `CACHE_PERSISTENT_ID` | – | cache connection (Redis / Memcached) |
| `REDIS_HOST`, `REDIS_PORT` | – | Redis connection for the `redis` cache/session stores |
| `SESSION_DRIVER` | `file` | Laravel session driver |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | – | create the first admin on start (runs `df:setup --force`, so it also works with `APP_ENV=production`). `ADMIN_PASSWORD` must be at least 16 characters |
| `ADMIN_FIRST_NAME`, `ADMIN_LAST_NAME` | – | optional admin name |
| `ADMIN_PHONE` | `not-provided` | optional admin phone (required by `df:setup`, defaulted when omitted) |
| `PACKAGE` | – | path/URL of a `.dfpkg` to import after `df:setup` |
| `LICENSE` | – | tier name under `/opt/dreamfactory/license/<tier>/composer.*` to install at start (needs internet) |
| `DF_LICENSE_KEY` | – | commercial license key |
| `DF_REGISTER_CONTACT` | – | registration contact e-mail |
| `DF_INSTALL` | `Docker` | install type reported to `/status`, `system/environment` and the fresh-instance phone-home. Images built for other channels bake their own value (e.g. `docker_trial`) |
| `DF_TRIAL_TOKEN` | – | **trial image only:** signed trial token from your dashboard at https://portal.dreamfactory.com. No effect on this image |
| `DF_TRIAL_PORTAL_URL`, `DF_IS_TRIAL`, `DF_TRIAL_HEARTBEAT` | – | **trial image only:** heartbeat target, trial flag, heartbeat on/off. Passed through to `.env` when set; no effect on this image |
| `JWT_TTL`, `JWT_REFRESH_TTL`, `ALLOW_FOREVER_SESSIONS` | – | session token lifetimes (`DF_JWT_TTL`, ...) |
| `APP_LOG_LEVEL` | `warning` | Laravel log level |
| `LOG_TO_STDOUT` | – | also tail `storage/logs/dreamfactory.log` to the container output |
| `EXTERNAL_IP` | – | public IP/hostname for generated URLs |
| `LOGSDB_HOST`, `LOGSDB_PORT`, `LOGSDB_DATABASE`, `LOGSDB_USERNAME`, `LOGSDB_PASSWORD`, `LOGSDB_ENABLED` | – | Logs DB (MongoDB) for the logger service |
| `SENDMAIL_DEFAULT_COMMAND`, `SSMTP_*` | – | outbound mail via ssmtp (`SSMTP_mailhub`, `SSMTP_AuthUser`, ...) |
| `ENABLE_MCP_DAEMON`, `ENABLE_SYSTEM_MCP_DAEMON` | – | start the MCP daemons (`df-mcp-server`, `df-system-mcp-server`) |

On start the entrypoint also recreates the `storage/` directory tree (`app`, `logs`, `databases`, `framework/{cache,sessions,views}`) when the mounted volume is empty, creates the sqlite file when `DB_CONNECTION=sqlite`, and fixes ownership to `www-data`.

<a name="licensed"></a>
## Running a Licensed Instance

### 1) Add the license files to the `df-docker` directory

### 2) Uncomment the `COPY composer.*` and `composer config --global --auth` lines of `Dockerfile` (lines 25 and 28) and put your GitHub access key in the latter

### 3) Uncomment the `DF_LICENSE_KEY` line near the end of `Dockerfile` (line 51) and add your license key

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

We mount a Postgres container that contains over 100k records to test without connecting your own data sets. To generate a REST API for this database, login to your DreamFactory instance and click the `Connect to Database` button on the home page. Choose PostgreSQL, then add an easily recalled namespace such as pgsql. You can enter anything you'd like into the description field. Click `Next` and enter the below connection details and then press the `Create & Test` button:

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
