#!/bin/bash
set -e

# Set NAME=VALUE in .env: replace an existing (or commented-out) line, else append.
# The value is escaped for sed's replacement side (\ | &) so signed tokens, URLs with
# query strings and passwords survive verbatim.
set_env_var() {
  local escaped
  escaped=$(printf '%s' "$2" | sed -e 's/[\\|&]/\\&/g')
  if grep -q "^#\?$1=" .env; then
    sed -i "s|^#\?$1=.*|$1=$escaped|" .env
  else
    echo "$1=$2" >> .env
  fi
}

# Print NAME's value from .env (empty when absent or commented out); strips one layer of quotes.
env_file_get() {
  sed -n "s/^$1=//p" .env | tail -n 1 | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

# storage/ is a named volume in every compose file we ship and a freshly created volume is
# EMPTY: until these directories exist every request 500s and a sqlite system DB cannot be
# opened. Recreate the tree (and the sqlite file) before anything touches the database.
ensure_storage_tree() {
  mkdir -p storage/app storage/databases storage/logs storage/scripting storage/wsdl \
           storage/framework/cache/data storage/framework/sessions storage/framework/views \
           bootstrap/cache
  if [ "$(env_file_get DB_CONNECTION)" = "sqlite" ]; then
    local db
    db=$(env_file_get DB_DATABASE)
    case "$db" in
      ":memory:") ;;
      "")   [ -e database/database.sqlite ] || touch database/database.sqlite ;;   # Laravel default path
      */*)  [ -e "$db" ] || { mkdir -p "$(dirname "$db")" && touch "$db"; } ;;
      *)    [ -e "storage/databases/$db" ] || touch "storage/databases/$db" ;;    # bare name: df-core relocates it here
    esac
  fi
  chown -R www-data:www-data storage bootstrap/cache
}

# df:setup enforces a 16-character minimum. With a shorter ADMIN_PASSWORD it falls
# into an interactive prompt with no TTY and spins forever, so refuse it up front.
require_admin_password_length() {
  if [ -n "$ADMIN_PASSWORD" ] && [ "${#ADMIN_PASSWORD}" -lt 16 ]; then
    echo "ERROR: ADMIN_PASSWORD must be at least 16 characters." >&2
    exit 1
  fi
}

# ---- Trial image (DF_INSTALL=docker_trial) only: volume reuse protection -----------------------
# Every trial's compose file names the same container and volume (dreamfactory-trial,
# dreamfactory-trial-storage), so starting a second trial on a machine that ran an earlier one
# mounts the earlier trial's storage: its sqlite system DB (with ITS admin user) and service
# credentials encrypted with ITS APP_KEY. df:setup only creates the admin on an empty DB, so the
# new trial's ADMIN_EMAIL/ADMIN_PASSWORD were silently ignored and the login from the dashboard
# failed. These two helpers make that situation work (admin) and visible (APP_KEY).

# The sha256 of the APP_KEY this volume was first booted with. Kept in storage/databases/ (inside
# the volume, but outside storage/app/, which the "files" service exposes over the API).
TRIAL_APP_KEY_HASH_FILE=storage/databases/.df-trial-app-key.sha256

# trial_app_key_guard FILE APP_KEY
# First boot of a volume: record sha256(APP_KEY) in FILE (0600 www-data). Later boots: if APP_KEY
# changed, print a prominent warning. Never refuses to boot. Sets TRIAL_APP_KEY_STATE to
# recorded | match | mismatch | nokey.
trial_app_key_guard() {
  local file="$1" key="$2" current stored
  TRIAL_APP_KEY_STATE=nokey
  [ -n "$key" ] || return 0
  current=$(printf '%s' "$key" | sha256sum | cut -d' ' -f1)
  if [ ! -s "$file" ]; then
    mkdir -p "$(dirname "$file")"
    ( umask 077; printf '%s\n' "$current" > "$file" )
    chown www-data:www-data "$file" 2>/dev/null || true
    chmod 600 "$file"
    TRIAL_APP_KEY_STATE=recorded
    echo "Trial: recorded the APP_KEY fingerprint for this storage volume"
    return 0
  fi
  stored=$(head -n 1 "$file" | tr -d '[:space:]')
  if [ "$stored" = "$current" ]; then
    TRIAL_APP_KEY_STATE=match
    return 0
  fi
  TRIAL_APP_KEY_STATE=mismatch
  cat >&2 <<'WARN'
************************************************************************************************
* WARNING: this storage volume was created with a DIFFERENT APP_KEY.
*
* The volume mounted at /opt/dreamfactory/storage (normally "dreamfactory-trial-storage") belongs
* to a different DreamFactory trial or installation than the APP_KEY this container was started
* with. Users, roles and services from that earlier instance are still in its system database,
* and any encrypted service credentials (database passwords, API keys, ...) stored there will NOT
* decrypt with the new APP_KEY: those services will fail until they are re-entered.
*
* To fix it, either:
*   - start the container with the ORIGINAL compose file / docker run command of the trial that
*     created this volume, or
*   - start the new trial on its own storage:
*       docker rm -f dreamfactory-trial
*       docker volume rm dreamfactory-trial-storage    (DELETES the earlier trial's data)
*     then run the new trial's compose file / docker run command again.
*
* The container keeps running; the new trial's admin user is created if it is missing.
************************************************************************************************
WARN
}

# trial_ensure_admin: make sure ADMIN_EMAIL is an active system admin in the system DB.
# Missing -> created exactly like df:setup does (User::createFirstAdmin, same validation and
# password hashing). Existing -> its password is left alone (the user may have changed it); only
# is_active / is_sys_admin are set. The password travels in the environment, never on a command
# line and never into the log. Best effort: a failure is logged and boot continues.
trial_ensure_admin() {
  local out
  if ! out=$(ADMIN_FIRST_NAME="${ADMIN_FIRST_NAME:-}" ADMIN_LAST_NAME="${ADMIN_LAST_NAME:-}" \
             ADMIN_PHONE="${ADMIN_PHONE:-not-provided}" php -d display_errors=stderr 2>&1 <<'PHP'
<?php
  require 'vendor/autoload.php';
  $app = require 'bootstrap/app.php';
  $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

  use DreamFactory\Core\Models\User;

  $email = (string) getenv('ADMIN_EMAIL');
  $password = (string) getenv('ADMIN_PASSWORD');
  $user = User::whereRaw('LOWER(email) = ?', [strtolower($email)])->first();
  if ($user) {
      $fix = [];
      if (!$user->is_active) {
          $fix['is_active'] = 1;
      }
      if (!$user->is_sys_admin) {
          $fix['is_sys_admin'] = 1;
      }
      if ($fix) {
          // Query-builder update: no model events, the password hash is never touched.
          User::whereKey($user->getKey())->update($fix);
      }
      User::resetAdminExists();
      echo 'RESULT existing ' . ($fix ? implode('+', array_keys($fix)) : 'unchanged') . PHP_EOL;
      exit(0);
  }
  $others = User::where('is_sys_admin', 1)->count();
  $first = (string) getenv('ADMIN_FIRST_NAME') ?: 'FirstName';
  $last = (string) getenv('ADMIN_LAST_NAME') ?: 'LastName';
  try {
      User::createFirstAdmin([
          'first_name' => $first,
          'last_name' => $last,
          'name' => $first . ' ' . $last,
          'email' => $email,
          'password' => $password,
          'password_confirmation' => $password,
          'phone' => (string) getenv('ADMIN_PHONE') ?: 'not-provided',
      ]);
  } catch (Illuminate\Validation\ValidationException $e) {
      echo 'RESULT failed ' . implode(' ', $e->validator->errors()->all()) . PHP_EOL;
      exit(1);
  }
  echo 'RESULT created ' . $others . PHP_EOL;
PHP
  ); then
    echo "Trial: WARNING could not ensure the admin user $ADMIN_EMAIL: $(printf '%s' "$out" | grep -v -F -- "$ADMIN_PASSWORD" | tail -n 3 | tr '\n' ' ')" >&2
    return 0
  fi
  local result
  result=$(printf '%s\n' "$out" | sed -n 's/^RESULT //p' | tail -n 1)
  case "$result" in
    "existing unchanged")
      echo "Trial: admin user $ADMIN_EMAIL exists (active system admin; password left unchanged)" ;;
    existing\ *)
      echo "Trial: admin user $ADMIN_EMAIL exists; set ${result#existing } (password left unchanged)" ;;
    "created 0")
      echo "Trial: created system admin $ADMIN_EMAIL" ;;
    created\ *)
      echo "Trial: created system admin $ADMIN_EMAIL (this volume already had ${result#created } other system admin(s) from an earlier instance)"
      if [ "${TRIAL_APP_KEY_STATE:-}" = recorded ]; then
        # A volume set up by an image that predates the APP_KEY fingerprint: the key it was
        # created with is unknown, but an admin other than this trial's means another instance.
        cat >&2 <<'WARN'
************************************************************************************************
* WARNING: this storage volume was already set up by a DIFFERENT DreamFactory instance (its system
* database has another admin user, and no record of the APP_KEY it was created with).
* If it belongs to an earlier trial, encrypted service credentials stored there will not decrypt
* with this trial's APP_KEY. To start this trial on its own storage:
*     docker rm -f dreamfactory-trial
*     docker volume rm dreamfactory-trial-storage    (DELETES the earlier instance's data)
* then run this trial's compose file / docker run command again.
************************************************************************************************
WARN
      fi ;;
    *)
      echo "Trial: WARNING unexpected result while ensuring admin user $ADMIN_EMAIL: $(printf '%s' "$out" | grep -v -F -- "$ADMIN_PASSWORD" | tail -n 3 | tr '\n' ' ')" >&2 ;;
  esac
}

# mail setup
CONF=/etc/ssmtp/ssmtp.conf
rm -f $CONF

# Check if the directory already exists.
if [ ! -d "$CONF" ]; then
  ### Take action if $DIR exists ###
  mkdir /etc/ssmtp -p
fi

# Filter the env variables for ssmtp configs and write them to the config file
env | awk -F'\n' '/^SSMTP_/ { print substr($1, 7) }' > "$CONF"

# Configure NGINX and www.conf
ln -s /etc/nginx/sites-available/dreamfactory.conf /etc/nginx/sites-enabled/dreamfactory.conf && \
sed -i "s/pm.max_children = 5/pm.max_children = 5000/" /etc/php/8.5/fpm/pool.d/www.conf && \
sed -i "s/pm.start_servers = 2/pm.start_servers = 150/" /etc/php/8.5/fpm/pool.d/www.conf && \
sed -i "s/pm.min_spare_servers = 1/pm.min_spare_servers = 100/" /etc/php/8.5/fpm/pool.d/www.conf && \
sed -i "s/pm.max_spare_servers = 3/pm.max_spare_servers = 200/" /etc/php/8.5/fpm/pool.d/www.conf && \
sed -i "s/pm = dynamic/pm = ondemand/" /etc/php/8.5/fpm/pool.d/www.conf && \
sed -i "s/worker_connections 768;/worker_connections 2048;/" /etc/nginx/nginx.conf && \
sed -i "s/keepalive_timeout 65;/keepalive_timeout 10;/" /etc/nginx/nginx.conf
# Install type reported to /status, system/environment and the fresh-instance phone-home.
# "Docker" unless the image (or the user) sets DF_INSTALL, e.g. docker_trial for the trial
# image. php-fpm clears the process environment, so the value has to live in .env.
set_env_var DF_INSTALL "${DF_INSTALL:-Docker}"

# Trial image settings (dreamfactory/df-trial reads them from .env). Never set on the
# public image, where this loop is a no-op. The token value is deliberately not echoed.
# DF_TRIAL_PROXY: outbound proxy for the heartbeat on firewalled hosts (php-fpm and cron never
# see HTTPS_PROXY from the container environment, so it has to travel through .env too).
trial_vars=("DF_TRIAL_TOKEN" "DF_TRIAL_PORTAL_URL" "DF_IS_TRIAL" "DF_TRIAL_HEARTBEAT" "DF_TRIAL_PROXY")
for var in "${trial_vars[@]}"
do
  if [ -n "${!var}" ]; then
    echo "Setting ${var}"
    set_env_var "${var}" "${!var}"
  fi
done

# update site configuration
# if no servername is provided use dreamfactory.app as default
sed -i "s;%SERVERNAME%;${SERVERNAME:=dreamfactory.app};g" /etc/nginx/sites-available/dreamfactory.conf

# Tell PHP-FPM/Laravel the original request was HTTPS when a TLS-terminating
# reverse proxy sits in front of this container (HTTPS_HEADER=on). "off" by
# default; leaving it off behind TLS makes Laravel emit http:// absolute URLs.
sed -i "s;%HTTPS_HEADER%;${HTTPS_HEADER:=off};g" /etc/nginx/sites-available/dreamfactory.conf

# Wait for MySQL to be ready if using MySQL
if [ "$DB_CONNECTION" = "mysql" ]; then
    echo "Waiting for MySQL to be ready..."
    for _ in {1..30}; do
        if mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; then
            echo "MySQL is ready"
            break
        fi
        echo "MySQL not ready yet... waiting"
        sleep 1
    done
fi

if [ ! -d "/opt/dreamfactory/public/dreamfactory" ]; then
    cd /opt/dreamfactory
    composer install --no-dev --ignore-platform-reqs
fi

# do we have configs for a cache ?
if [ -n "$CACHE_DRIVER" ]; then
  echo "Setting CACHE_DRIVER, CACHE_HOST, CACHE_DATABASE"
  sed -i "s/#CACHE_HOST=/CACHE_HOST=$CACHE_HOST/" .env
  sed -i "s/#CACHE_DATABASE=2/CACHE_DATABASE=$CACHE_DATABASE/" .env
  sed -i "s/CACHE_DRIVER=file/CACHE_DRIVER=$CACHE_DRIVER/" .env
  # 7.x .env-dist and config/cache.php read CACHE_STORE, not CACHE_DRIVER; without this
  # line the compose Redis settings were written but silently ignored (file cache stayed on).
  set_env_var CACHE_STORE "$CACHE_DRIVER"
fi

if [ -n "$CACHE_PORT" ]; then
  echo "Setting CACHE_PORT"
  sed -i "s/#CACHE_PORT=/CACHE_PORT=$CACHE_PORT/" .env
fi

if [ -n "$CACHE_USERNAME" ]; then
  echo "Setting CACHE_USERNAME"
  sed -i "s/#CACHE_USERNAME=/CACHE_USERNAME=$CACHE_USERNAME/" .env
fi

if [ -n "$CACHE_WEIGHT" ]; then
  echo "Setting CACHE_WEIGHT"
  sed -i "s/#CACHE_WEIGHT=/CACHE_WEIGHT=$CACHE_WEIGHT/" .env
fi

if [ -n "$CACHE_PERSISTENT_ID" ]; then
  echo "Setting CACHE_PERSISTENT_ID"
  sed -i "s/#CACHE_PERSISTENT_ID=/CACHE_PERSISTENT_ID=$CACHE_PERSISTENT_ID/" .env
fi

if [ -n "$CACHE_PASSWORD" ]; then
  echo "Setting CACHE_PASSWORD"
  sed -i "s/#CACHE_PASSWORD=/CACHE_PASSWORD=$CACHE_PASSWORD/" .env
fi

# do we have configs for an external DB ?
if [ -n "$DB_DRIVER" ]; then
  echo "Setting DB_DRIVER, DB_HOST, DB_USERNAME, DB_PASSWORD, and DB_DATABASE"
  # set_env_var (not a bare sed) so values with "/" work, e.g. DB_DRIVER=sqlite with an
  # absolute DB_DATABASE path inside the storage volume.
  set_env_var DB_CONNECTION "$DB_DRIVER"
  db_vars=("DB_HOST" "DB_USERNAME" "DB_PASSWORD" "DB_DATABASE")
  for var in "${db_vars[@]}"
  do
    if [ -n "${!var}" ]; then
      set_env_var "${var}" "${!var}"
    fi
  done
fi

if [ -n "$DB_PORT" ] && [[ $DB_PORT != *":"* ]]; then
  echo "Setting DB_PORT"
  set_env_var DB_PORT "$DB_PORT"
fi

ensure_storage_tree

# do we have an existing APP_KEY we should reuse ?
if [ -n "$APP_KEY" ]; then
  if [ "${DF_INSTALL:-}" = "docker_trial" ]; then
    echo "Setting APP_KEY from environment"   # trial logs end up in support tickets: no secret
  else
    echo "Setting APP_KEY=$APP_KEY from environment"
  fi
  sed -i "s#APP_KEY=.*#APP_KEY=$APP_KEY#" .env
else
  # generate AppKey on first run
  if [ ! -e .first_run_done ]; then
    echo "Generating APP_KEY"
    php artisan key:generate
    touch .first_run_done
  fi
fi

# Trial image: fingerprint the APP_KEY this storage volume belongs to (warns on a foreign volume).
if [ "${DF_INSTALL:-}" = "docker_trial" ]; then
  trial_app_key_guard "$TRIAL_APP_KEY_HASH_FILE" "$(env_file_get APP_KEY)"
fi

if [ -n "$LICENSE" ] && [ -f "/opt/dreamfactory/license/$LICENSE/composer.lock" ]; then
    echo "Installing $LICENSE packages..."
    cp /opt/dreamfactory/license/"$LICENSE"/composer.* /opt/dreamfactory
    composer install --no-dev --ignore-platform-reqs
    php artisan migrate --seed --force
    php artisan cache:clear
    php artisan config:clear
fi

# do we have first user provided in env?
require_admin_password_length
if [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
    # df:setup requires a phone number but nothing else does; default it so a signup form
    # that only asked for email + password can still bootstrap the first admin.
    ADMIN_PHONE="${ADMIN_PHONE:-not-provided}"
    lastExitCode=1
    echo "Setting up database and creating first admin user"
    while [ "$lastExitCode" != 0 ] ; do
        # --force: with APP_ENV=production (the trial image) migrate/db:seed would otherwise ask
        # for confirmation, get "Command cancelled" without a TTY and leave the DB empty.
        if [ -n "$ADMIN_FIRST_NAME" ] && [ -n "$ADMIN_LAST_NAME" ]; then
            output=$(php artisan df:setup --force --admin_email "$ADMIN_EMAIL" --admin_password "$ADMIN_PASSWORD" --admin_first_name "$ADMIN_FIRST_NAME" --admin_last_name "$ADMIN_LAST_NAME" --admin_phone "$ADMIN_PHONE")
        else
            output=$(php artisan df:setup --force --admin_email "$ADMIN_EMAIL" --admin_password "$ADMIN_PASSWORD" --admin_phone "$ADMIN_PHONE")
        fi

        if [[ "$output" != *"SQLSTATE[HY000]"* ]] && [[ "$output" != *"No suitable servers found"* ]]; then
            lastExitCode=0
        else
            # Show the reason: a missing table or a wrong credential looks exactly like "not ready yet".
            echo "$output" | grep -E "SQLSTATE|No suitable servers" | head -n 2 >&2
            echo "Database connection failed. Wait 5 seconds and retry..."
            sleep 5s
        fi
    done;

    echo "$output"

    # Do we have a package to import?
    if [ -n "$PACKAGE" ]; then
      echo "Importing package $PACKAGE"
      php artisan df:import-pkg "$PACKAGE" --delete
    fi
fi

# Trial image: df:setup above only creates the admin on an EMPTY system DB. When the storage volume
# already holds a database (a restart, or another trial's volume), make sure THIS trial's admin
# exists and is an active system admin, on every boot.
if [ "${DF_INSTALL:-}" = "docker_trial" ] && [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
  trial_ensure_admin
fi

chown -R www-data:www-data storage/
chown -R www-data:www-data bootstrap/cache/

# do we have configs for Session management ?
jwt_vars=("JWT_TTL" "JWT_REFRESH_TTL" "ALLOW_FOREVER_SESSIONS")
for var in "${jwt_vars[@]}"
do
  if [ -n "${!var}" ]; then
    echo "Setting DF_${var}"
    sed -i "s/##DF_${var}=.*/DF_${var}=${!var}/" .env
  fi
done

if [ -n "$LOG_TO_STDOUT" ]; then
  echo "Also writing dreamfactory.log messages to STDOUT"
  # we cannot ln the log to stdout like with nginx logs, so we continuously tail it
  tail --pid $$ -F /opt/dreamfactory/storage/logs/dreamfactory.log &
fi

if [ -n "$APP_LOG_LEVEL" ]; then
  echo "Setting APP_LOG_LEVEL"
  sed -i "s/#APP_LOG_LEVEL=warning/APP_LOG_LEVEL=$APP_LOG_LEVEL/" .env
fi

if [ -n "$SESSION_DRIVER" ]; then
  echo "" >> .env
  echo "SESSION_DRIVER=$SESSION_DRIVER" >> .env
fi

if [ -n "$REDIS_HOST" ]; then
  echo "REDIS_HOST=$REDIS_HOST" >> .env
fi

if [ -n "$REDIS_PORT" ]; then
  echo "REDIS_PORT=$REDIS_PORT" >> .env
fi

if [ -n "$EXTERNAL_IP" ]; then
  echo "Setting EXTERNAL_IP"
  sed -i "s/#EXTERNAL_IP=/EXTERNAL_IP=$EXTERNAL_IP/" .env
fi

logsdb_vars=("LOGSDB_HOST" "LOGSDB_PORT" "LOGSDB_DATABASE" "LOGSDB_USERNAME" "LOGSDB_PASSWORD" "LOGSDB_ENABLED")
for var in "${logsdb_vars[@]}"
do
  if [ -n "${!var}" ]; then
    echo "Setting ${var}"
    sed -i "s/#${var}=.*/${var}=${!var}/" .env
  fi
done

if [ -n "$DF_REGISTER_CONTACT" ]; then
  echo "Setting DF_REGISTER_CONTACT"
  sed -i "s/#DF_REGISTER_CONTACT=/DF_REGISTER_CONTACT=$DF_REGISTER_CONTACT/" .env
fi

if [ -n "$DF_LICENSE_KEY" ]; then
  echo "Setting DF_LICENSE_KEY"
  # 7.7 .env-dist has no #DF_LICENSE_KEY= placeholder, so a plain sed matched
  # nothing and the key was silently dropped (#124).
  set_env_var DF_LICENSE_KEY "$DF_LICENSE_KEY"
fi

if [ -n "$SENDMAIL_DEFAULT_COMMAND" ]; then
  echo "Setting SENDMAIL_DEFAULT_COMMAND=$SENDMAIL_DEFAULT_COMMAND"
  sed -i "s/#SENDMAIL_DEFAULT_COMMAND=.*/SENDMAIL_DEFAULT_COMMAND=\"$(echo "$SENDMAIL_DEFAULT_COMMAND" | sed 's/\//\\\//g')\"/" .env
fi

# Start MCP daemon if enabled
if [ -n "$ENABLE_MCP_DAEMON" ]; then
  MCP_DAEMON_DIR="/opt/dreamfactory/vendor/dreamfactory/df-mcp-server/daemon"
  if [ -f "${MCP_DAEMON_DIR}/package.json" ]; then
    # Ensure node_modules are installed (may be missing if vendor was updated)
    if [ ! -d "${MCP_DAEMON_DIR}/node_modules" ]; then
      echo "Installing MCP daemon dependencies..."
      (cd "${MCP_DAEMON_DIR}" && npm install --production)
    fi
    echo "Starting MCP daemon..."
    /opt/dreamfactory/vendor/dreamfactory/df-mcp-server/scripts/start-daemon.sh &
    MCP_DAEMON_PID=$!
    echo "MCP daemon started (PID: ${MCP_DAEMON_PID})"
  else
    echo "Warning: ENABLE_MCP_DAEMON is set but MCP daemon package not found"
  fi
fi

if [ -n "$ENABLE_SYSTEM_MCP_DAEMON" ]; then
  SYSTEM_MCP_DIR="/opt/dreamfactory/vendor/dreamfactory/df-system-mcp-server"
  if [ -f "${SYSTEM_MCP_DIR}/package.json" ]; then
    # Ensure node_modules are installed (may be missing if vendor was updated)
    if [ ! -d "${SYSTEM_MCP_DIR}/node_modules" ]; then
      echo "Installing System API MCP daemon dependencies..."
      (cd "${SYSTEM_MCP_DIR}" && npm install --production)
    fi
    echo "Starting System API MCP daemon..."
    /opt/dreamfactory/vendor/dreamfactory/df-mcp-server/scripts/start-system-daemon.sh &
    SYSTEM_MCP_DAEMON_PID=$!
    echo "System API MCP daemon started (PID: ${SYSTEM_MCP_DAEMON_PID})"
  else
    echo "Warning: ENABLE_SYSTEM_MCP_DAEMON is set but df-system-mcp-server package not found"
  fi
fi

# start php8.5-fpm
service php8.5-fpm start

# start cron service for df-scheduler (and /etc/cron.d/df-trial on the trial image)
service cron start

# Trial image: one best-effort heartbeat on EVERY container start (cron sends the hourly ones,
# /etc/cron.d/df-trial). It also carries the portal's signed revocation, so a revoked trial locks
# as soon as it is restarted. Detached in the background so it never delays boot (nginx is exec'd
# right away; the heartbeat has a 3 s HTTP timeout and fails silently). Not gated on DF_TRIAL_TOKEN in
# the container environment: the token may live only in /opt/dreamfactory/.env (the package
# reads it from there and skips quietly when there is none). Runs as www-data so any file it
# creates under storage/ stays writable by php-fpm. Only when the dreamfactory/df-trial package
# is installed (a file test, no PHP), so the public image never shells out here.
if [ -f /opt/dreamfactory/vendor/dreamfactory/df-trial/composer.json ]; then
  echo "Sending trial heartbeat (background)"
  ( cd /opt/dreamfactory && runuser -u www-data -- php artisan df:trial heartbeat >/dev/null 2>&1 ) </dev/null >/dev/null 2>&1 &
fi

# start nginx
exec /usr/sbin/nginx -g "daemon off;"
