#!/usr/bin/env bash
# Smoke tests for themusicdev/php-apache
# Usage: tests/smoke-test.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

PHP_VERSION="${PHP_VERSION:-8.5.12}"
RT="themusicdev/php-apache:${PHP_VERSION}"
DV="themusicdev/php-apache:${PHP_VERSION}-dev"

PIDS=()
cleanup() {
    for c in "${CIDS[@]}"; do docker rm -f "$c" >/dev/null 2>&1 || true; done
}
trap cleanup EXIT

CIDS=()
run_fixtures() {
    local id
    id=$(docker run -d --rm -p 0:80 -v "$ROOT/tests/fixtures/app-cake:/var/www/html" "$RT")
    CIDS+=("$id")
    id=$(docker run -d --rm -p 0:80 \
        -e APACHE_DOCUMENT_ROOT=/var/www/html/public \
        -v "$ROOT/tests/fixtures/app-slim:/var/www/html" "$RT")
    CIDS+=("$id")
    id=$(docker run -d --rm -p 0:80 -v "$ROOT/tests/fixtures/app-cake:/var/www/html" "$DV")
    CIDS+=("$id")
}

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES+1)); }
FAILURES=0

port_of() { docker port "$1" 80 | awk -F'[: ]' 'NR==1{print $NF}'; }

echo "== Building targets =="
docker build --target runtime -t "$RT" "$ROOT"
docker build --target dev -t "$DV" "$ROOT"
echo "== Build OK =="
pass "both targets build"

echo "== Starting fixtures =="
run_fixtures
sleep 3

CAKE="${CIDS[0]}" SLIM="${CIDS[1]}" DEV="${CIDS[2]}"
CAKE_PORT=$(port_of "$CAKE")
SLIM_PORT=$(port_of "$SLIM")
DEV_PORT=$(port_of "$DEV")

echo "== php -v / extensions (runtime) =="
PV=$(docker exec "$CAKE" php -r 'echo PHP_VERSION;')
[[ "$PV" == 8.5.* ]] && pass "php -v is 8.5.x ($PV)" || fail "php -v is $PV"

for ext in intl pdo_mysql mysqli zip gd bcmath exif mbstring simplexml pdo_sqlite; do
    docker exec "$CAKE" php -r "exit((int)!extension_loaded('$ext'));" \
        && pass "ext: $ext" || fail "ext: $ext missing"
done
docker exec "$CAKE" php -r 'exit((int)!function_exists("opcache_get_status"));' \
    && pass "ext: opcache" || fail "ext: opcache missing"
docker exec "$CAKE" php -m | grep -qi '^xdebug' \
    && fail "xdebug present in runtime" || pass "xdebug absent in runtime"

echo "== Dev target =="
docker exec "$DEV" php -m | grep -qi '^xdebug' \
    && pass "xdebug present in dev" || fail "xdebug missing in dev"
# xdebug.mode ini is not reliably introspectable (XDEBUG_MODE env wins) —
# assert the shipped default via the image env instead.
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$DV" | grep -q '^XDEBUG_MODE=off$' \
    && pass "xdebug default off (XDEBUG_MODE=off)" || fail "xdebug default off"
docker run --rm --entrypoint php -e XDEBUG_MODE=debug "$DV" -r 'exit(getenv("XDEBUG_MODE") === "debug" ? 0 : 1);' \
    && pass "XDEBUG_MODE env override reaches PHP" || fail "XDEBUG_MODE env override"
docker exec "$DEV" node -v >/dev/null 2>&1 && pass "node present in dev" || fail "node missing in dev"
docker exec "$DEV" mysql --version >/dev/null 2>&1 && pass "mysql client present in dev" || fail "mysql client missing in dev"

echo "== webroot docroot (default) =="
body=$(curl -fsS "http://127.0.0.1:$CAKE_PORT/")
[[ "$body" == PHP_VERSION=8.5.* ]] && pass "index.php served from webroot" || { fail "webroot index: $body"; echo "$body" | head; }

echo "== rewrite =="
body=$(curl -fsS "http://127.0.0.1:$CAKE_PORT/pretty-url" | grep -c "PHP_VERSION=")
[[ "$body" == 1 ]] && pass "pretty URL rewritten to index.php" || fail "rewrite failed"

echo "== APACHE_DOCUMENT_ROOT switch =="
body=$(curl -fsS "http://127.0.0.1:$SLIM_PORT/" | grep -c "PHP_VERSION=")
[[ "$body" == 1 ]] && pass "document root switched to /public" || fail "docroot switch failed"

echo "== proxy headers =="
h=$(curl -fsS -H 'X-Forwarded-For: 1.2.3.4' -H 'X-Forwarded-Proto: https' "http://127.0.0.1:$CAKE_PORT/")
echo "$h" | grep -q '^HTTPS=on$' && pass "X-Forwarded-Proto https → HTTPS=on" || fail "HTTPS not set"
echo "$h" | grep -q '^REMOTE_ADDR=1.2.3.4$' && pass "X-Forwarded-For trusted → REMOTE_ADDR" || { fail "REMOTE_ADDR not rewritten"; echo "$h" | grep REMOTE_ADDR; }

echo "== tmp/logs housekeeping =="
docker exec -u www-data "$CAKE" sh -c 'echo ok > /var/www/html/tmp/.probe && rm /var/www/html/tmp/.probe' \
    && pass "tmp/ writable by www-data" || fail "tmp/ not writable by www-data"

echo "== healthcheck defined =="
docker inspect --format '{{.Config.Healthcheck.Test}}' "$CAKE" | grep -q curl \
    && pass "HEALTHCHECK present" || fail "HEALTHCHECK missing"

echo
if [[ $FAILURES -gt 0 ]]; then
    echo "$FAILURES test(s) failed"
    exit 1
fi
echo "all smoke tests passed"