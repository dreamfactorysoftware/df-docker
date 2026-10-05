#!/bin/bash
# Unit checks for the helper functions in docker-entrypoint.sh (#124, docker-trial).
# Run: bash tests/entrypoint-test.sh   (no Docker needed; chown is stubbed)
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
eval "$(sed -n '/^set_env_var()/,/^}/p; /^env_file_get()/,/^}/p; /^ensure_storage_tree()/,/^}/p; /^require_admin_password_length()/,/^}/p' "$root/docker-entrypoint.sh")"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT; cd "$tmp"
fail() { echo "FAIL: $1" >&2; exit 1; }
chown() { :; }   # ensure_storage_tree chowns to www-data; not possible (or wanted) in a unit test

# --- set_env_var -------------------------------------------------------------------------
printf 'APP_NAME=DreamFactory\n' > .env
set_env_var DF_LICENSE_KEY abc123
grep -qx 'DF_LICENSE_KEY=abc123' .env || fail "append when no placeholder (7.7 .env-dist)"

printf '#DF_LICENSE_KEY=\nX=1\n' > .env
set_env_var DF_LICENSE_KEY abc123
grep -qx 'DF_LICENSE_KEY=abc123' .env && [ "$(grep -c DF_LICENSE_KEY .env)" = 1 ] || fail "replace commented placeholder in place"

printf 'DF_LICENSE_KEY=old\n' > .env
set_env_var DF_LICENSE_KEY new
grep -qx 'DF_LICENSE_KEY=new' .env && [ "$(grep -c DF_LICENSE_KEY .env)" = 1 ] || fail "overwrite existing value without duplicating"

printf 'DF_INSTALL=GitHub\n' > .env
set_env_var DF_INSTALL docker_trial
grep -qx 'DF_INSTALL=docker_trial' .env || fail "DF_INSTALL override"

# sed metacharacters in values: & (whole match), | (our delimiter), \ (escape)
printf 'DF_TRIAL_PORTAL_URL=x\n' > .env
set_env_var DF_TRIAL_PORTAL_URL 'https://portal.example.com/start?a=1&b=2|c\d'
grep -qxF 'DF_TRIAL_PORTAL_URL=https://portal.example.com/start?a=1&b=2|c\d' .env || fail "value with & | \\ survives sed replacement: $(cat .env)"

printf 'DF_TRIAL_TOKEN=\n' > .env
tok='DFT1.eyJleHAiOjE3OTM2NTcwOTJ9.nJuWaQ2oUXDy_zYMwfb_kvLH1FOTvNGciYrF4At9Tqwq-_RPLTU4QM2eJgLxon_QZHBQ'
set_env_var DF_TRIAL_TOKEN "$tok"
grep -qxF "DF_TRIAL_TOKEN=$tok" .env || fail "signed token survives verbatim"

printf 'DB_DATABASE=dreamfactory\n' > .env
set_env_var DB_DATABASE /opt/dreamfactory/storage/databases/dreamfactory.sqlite
grep -qxF 'DB_DATABASE=/opt/dreamfactory/storage/databases/dreamfactory.sqlite' .env || fail "absolute path with slashes"

# --- env_file_get ------------------------------------------------------------------------
printf '#DB_DATABASE=\nDB_CONNECTION=sqlite\nQUOTED="a b"\nSINGLE='"'"'c'"'"'\n' > .env
[ "$(env_file_get DB_CONNECTION)" = sqlite ] || fail "env_file_get plain value"
[ "$(env_file_get DB_DATABASE)" = "" ] || fail "env_file_get commented placeholder is empty"
[ "$(env_file_get MISSING)" = "" ] || fail "env_file_get missing key is empty"
[ "$(env_file_get QUOTED)" = "a b" ] || fail "env_file_get strips double quotes"
[ "$(env_file_get SINGLE)" = "c" ] || fail "env_file_get strips single quotes"

# --- ensure_storage_tree -----------------------------------------------------------------
# empty volume + sqlite at an absolute path inside it (trial image layout)
rm -rf storage bootstrap database; mkdir -p database
printf 'DB_CONNECTION=sqlite\nDB_DATABASE=%s/storage/databases/dreamfactory.sqlite\n' "$tmp" > .env
ensure_storage_tree
for d in storage/app storage/databases storage/logs storage/framework/cache/data storage/framework/sessions storage/framework/views bootstrap/cache; do
  [ -d "$d" ] || fail "ensure_storage_tree did not create $d"
done
[ -f storage/databases/dreamfactory.sqlite ] || fail "sqlite file at absolute path not touched"

# bare file name -> df-core relocates it into storage/databases/
rm -rf storage; printf 'DB_CONNECTION=sqlite\nDB_DATABASE=trial.sqlite\n' > .env
ensure_storage_tree
[ -f storage/databases/trial.sqlite ] || fail "bare sqlite name not touched in storage/databases"

# Laravel default (DB_DATABASE unset) -> database/database.sqlite
rm -rf storage database; mkdir database; printf 'DB_CONNECTION=sqlite\n#DB_DATABASE=\n' > .env
ensure_storage_tree
[ -f database/database.sqlite ] || fail "default sqlite path not touched"

# existing sqlite content must never be clobbered
printf 'data' > storage/databases/keep.sqlite; printf 'DB_CONNECTION=sqlite\nDB_DATABASE=keep.sqlite\n' > .env
ensure_storage_tree
[ "$(cat storage/databases/keep.sqlite)" = data ] || fail "existing sqlite file was modified"

# mysql: directories only, no sqlite file
rm -rf storage database; printf 'DB_CONNECTION=mysql\nDB_DATABASE=dreamfactory\n' > .env
ensure_storage_tree
[ -d storage/framework/views ] && [ ! -e storage/databases/dreamfactory ] || fail "mysql must not create a sqlite file"

# --- require_admin_password_length -------------------------------------------------------
(ADMIN_PASSWORD=short require_admin_password_length 2>/dev/null) && fail "short ADMIN_PASSWORD was accepted"
(ADMIN_PASSWORD=sixteen-chars-ok1 require_admin_password_length) || fail "16-char ADMIN_PASSWORD was rejected"
(ADMIN_PASSWORD='' require_admin_password_length) || fail "unset ADMIN_PASSWORD must be a no-op"

echo "ok: entrypoint helpers"
