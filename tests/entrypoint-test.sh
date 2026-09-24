#!/bin/bash
# Checks for the helper functions in docker-entrypoint.sh (#124). Run: bash tests/entrypoint-test.sh
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
eval "$(sed -n '/^set_env_var()/,/^}/p; /^require_admin_password_length()/,/^}/p' "$root/docker-entrypoint.sh")"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT; cd "$tmp"
fail() { echo "FAIL: $1" >&2; exit 1; }

printf 'APP_NAME=DreamFactory\n' > .env
set_env_var DF_LICENSE_KEY abc123
grep -qx 'DF_LICENSE_KEY=abc123' .env || fail "append when no placeholder (7.7 .env-dist)"

printf '#DF_LICENSE_KEY=\nX=1\n' > .env
set_env_var DF_LICENSE_KEY abc123
grep -qx 'DF_LICENSE_KEY=abc123' .env && [ "$(grep -c DF_LICENSE_KEY .env)" = 1 ] || fail "replace commented placeholder in place"

printf 'DF_LICENSE_KEY=old\n' > .env
set_env_var DF_LICENSE_KEY new
grep -qx 'DF_LICENSE_KEY=new' .env && [ "$(grep -c DF_LICENSE_KEY .env)" = 1 ] || fail "overwrite existing value without duplicating"

(ADMIN_PASSWORD=short require_admin_password_length 2>/dev/null) && fail "short ADMIN_PASSWORD was accepted"
(ADMIN_PASSWORD=sixteen-chars-ok1 require_admin_password_length) || fail "16-char ADMIN_PASSWORD was rejected"
(ADMIN_PASSWORD= require_admin_password_length) || fail "unset ADMIN_PASSWORD must be a no-op"

echo "ok: entrypoint helpers"
