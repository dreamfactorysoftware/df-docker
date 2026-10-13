#!/usr/bin/env bash
# Build Dockerfile.openshift on top of a base image and run it as a random UID in group 0 (what OpenShift does).
# Usage: test-openshift.sh [base-image]   (default df-771-web:latest)
set -u
BASE=${1:-df-771-web:latest}; cd "$(dirname "$0")"
docker rm -f dfos >/dev/null 2>&1
docker build -q -f Dockerfile.openshift --build-arg BASE=$BASE -t df-openshift-test . 2>&1 | tail -1 || exit 1
docker network create dfos-net >/dev/null 2>&1
docker ps -q -f name=dfos-mysql | grep -q . || { docker run -d --name dfos-mysql --network dfos-net -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=dreamfactory -e MYSQL_USER=df -e MYSQL_PASSWORD=df mysql:8.0.44 >/dev/null; sleep 20; }
docker run -d --name dfos --network dfos-net -u 123456:0 -p 8089:8080 \
  -e APP_KEY="base64:$(openssl rand -base64 32)" -e DB_CONNECTION=mysql -e DB_HOST=dfos-mysql -e DB_PORT=3306 \
  -e DB_DATABASE=dreamfactory -e DB_USERNAME=df -e DB_PASSWORD=df \
  -e ADMIN_EMAIL=admin@dreamfactory.com -e ADMIN_PASSWORD='OpenShiftTest2026!!' df-openshift-test >/dev/null
for i in $(seq 1 80); do c=$(curl -s -m3 -o /dev/null -w %{http_code} http://localhost:8089/api/v2/system/environment); [ "$c" = "200" ] && break; docker ps -q -f name=^dfos$ | grep -q . || break; sleep 3; done
echo "after $((i*3))s: http $c"
docker exec dfos id 2>/dev/null | head -1
docker exec dfos ps -eo user,args 2>/dev/null | grep -E "nginx|php-fpm" | grep -v grep | awk '{print $1, $2, $3}' | sort -u | head -4
echo "--- errors in log:"; docker logs dfos 2>&1 | grep -iE "error|denied|emerg|fail|permission|not found|unbound" | grep -viE "0 errors|error_log" | head -8
echo "--- tail:"; docker logs dfos 2>&1 | tail -3
