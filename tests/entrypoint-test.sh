#!/bin/bash
# Unit checks for the helper functions in docker-entrypoint.sh (#124, docker-trial).
# Run: bash tests/entrypoint-test.sh   (no Docker needed; chown is stubbed)
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
eval "$(sed -n '/^set_env_var()/,/^}/p; /^env_file_get()/,/^}/p; /^ensure_storage_tree()/,/^}/p; /^require_admin_password_length()/,/^}/p; /^TRIAL_APP_KEY_HASH_FILE=/p; /^trial_app_key_guard()/,/^}/p; /^trial_ensure_admin()/,/^}/p' "$root/docker-entrypoint.sh")"
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

# --- trial_app_key_guard (DF_INSTALL=docker_trial) ---------------------------------------
[ "$TRIAL_APP_KEY_HASH_FILE" = storage/databases/.df-trial-app-key.sha256 ] || fail "hash file must live outside storage/app (files service root)"
rm -rf storage; mkdir -p storage/databases
keyA='base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='; keyB='base64:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB='
out=$(trial_app_key_guard "$TRIAL_APP_KEY_HASH_FILE" "$keyA" 2>&1); trial_app_key_guard "$TRIAL_APP_KEY_HASH_FILE" "$keyA" >/dev/null 2>&1
[ -s "$TRIAL_APP_KEY_HASH_FILE" ] || fail "first boot must record the APP_KEY fingerprint"
[ "$(head -n1 "$TRIAL_APP_KEY_HASH_FILE")" = "$(printf '%s' "$keyA" | sha256sum | cut -d' ' -f1)" ] || fail "fingerprint is sha256(APP_KEY)"
grep -qF "$keyA" "$TRIAL_APP_KEY_HASH_FILE" && fail "raw APP_KEY written to disk"
[ "$(stat -c %a "$TRIAL_APP_KEY_HASH_FILE")" = 600 ] || fail "fingerprint file must be 0600"
case "$out" in *"$keyA"*) fail "APP_KEY echoed";; esac
trial_app_key_guard "$TRIAL_APP_KEY_HASH_FILE" "$keyA" >/dev/null 2>&1; [ "$TRIAL_APP_KEY_STATE" = match ] || fail "same key -> match"
out=$(trial_app_key_guard "$TRIAL_APP_KEY_HASH_FILE" "$keyB" 2>&1)
case "$out" in *"WARNING: this storage volume was created with a DIFFERENT APP_KEY"*) ;; *) fail "different key must warn";; esac
case "$out" in *"$keyB"*|*"$keyA"*) fail "warning must not print a key";; esac
trial_app_key_guard "$TRIAL_APP_KEY_HASH_FILE" "$keyB" >/dev/null 2>&1 || fail "mismatch must not fail the boot"
[ "$TRIAL_APP_KEY_STATE" = mismatch ] || fail "different key -> mismatch"
[ "$(head -n1 "$TRIAL_APP_KEY_HASH_FILE")" = "$(printf '%s' "$keyA" | sha256sum | cut -d' ' -f1)" ] || fail "mismatch must keep the ORIGINAL fingerprint (warn on every boot)"
trial_app_key_guard "$TRIAL_APP_KEY_HASH_FILE" "" >/dev/null 2>&1; [ "$TRIAL_APP_KEY_STATE" = nokey ] || fail "empty key -> nokey"

# --- trial_ensure_admin (php stubbed: only the shell-side contract is tested here) -------
export ADMIN_EMAIL='kevin.mcgahey+volfix@example.com' ADMIN_PASSWORD='S3cret-Pass-Word-1234'
# shellcheck disable=SC2329  # invoked by the eval'd trial_ensure_admin
php() { cat >/dev/null; printf '%s\n' "${PHP_STUB_OUT}"; return "${PHP_STUB_RC:-0}"; }
PHP_STUB_OUT='RESULT created 0'; out=$(trial_ensure_admin 2>&1)
[ "$out" = "Trial: created system admin $ADMIN_EMAIL" ] || fail "created line (email with +): $out"
PHP_STUB_OUT='RESULT existing unchanged'; out=$(trial_ensure_admin 2>&1)
case "$out" in *"exists (active system admin; password left unchanged)"*) ;; *) fail "existing line: $out";; esac
PHP_STUB_OUT='RESULT existing is_active+is_sys_admin'; out=$(trial_ensure_admin 2>&1)
case "$out" in *"set is_active+is_sys_admin"*) ;; *) fail "existing+fixed line: $out";; esac
TRIAL_APP_KEY_STATE=recorded PHP_STUB_OUT='RESULT created 1'; out=$(trial_ensure_admin 2>&1)
case "$out" in *"1 other system admin"*"already set up by a DIFFERENT DreamFactory instance"*) ;; *) fail "legacy volume warning: $out";; esac
TRIAL_APP_KEY_STATE=match PHP_STUB_OUT='RESULT created 1'; out=$(trial_ensure_admin 2>&1)
case "$out" in *"DIFFERENT DreamFactory instance"*) fail "legacy warning only when the fingerprint was just recorded";; esac
PHP_STUB_RC=1 PHP_STUB_OUT="boom with $ADMIN_PASSWORD inside"; out=$(trial_ensure_admin 2>&1) || fail "php failure must not fail the boot"
case "$out" in *"could not ensure the admin user"*) ;; *) fail "failure line: $out";; esac
case "$out" in *"$ADMIN_PASSWORD"*) fail "password leaked into the log";; esac
unset -f php

echo "ok: entrypoint helpers"
