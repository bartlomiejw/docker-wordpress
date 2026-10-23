#!/usr/bin/env bash
# Bootstrap a fresh checkout. Safe to re-run: existing files are kept.
#   1. .env from .env.example with random passwords and salts
#   2. local TLS certificate in ./certs
#   3. Bedrock project in ./app (composer create-project + Redis object cache)
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"

command -v openssl >/dev/null 2>&1 || die "openssl is required"

random() { openssl rand -base64 96 | tr -dc 'A-Za-z0-9' | cut -c1-"$1"; }

set_env() {
    local key=$1 value=$2 tmp
    tmp="$(mktemp)"
    awk -v k="$key" -v v="$value" 'index($0, k "=") == 1 { print k "=" v; next } { print }' .env > "$tmp"
    mv "$tmp" .env
}

# 1. Environment -----------------------------------------------------------
if [[ -f .env ]]; then
    log ".env exists - keeping it"
else
    log "Creating .env with generated secrets"
    cp .env.example .env
    for key in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY \
               AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
        set_env "$key" "$(random 64)"
    done
    for key in DB_PASSWORD DB_ROOT_PASSWORD WP_ADMIN_PASSWORD; do
        set_env "$key" "$(random 24)"
    done
    dashboard_password="$(random 20)"
    set_env TRAEFIK_DASHBOARD_PASSWORD "$dashboard_password"
    set_env TRAEFIK_BASIC_AUTH_USERS "'admin:$(openssl passwd -apr1 "$dashboard_password")'"
fi
load_env

# 2. Certificates (local mode only) -----------------------------------------
if [[ "${MODE:-local}" == "prod" ]]; then
    log "Production mode - certificates come from Let's Encrypt"
elif [[ -f certs/local.pem && -f certs/local-key.pem ]]; then
    log "Certificates exist - keeping them"
else
    "$ROOT_DIR/scripts/generate-certs.sh"
fi

# 3. Bedrock ----------------------------------------------------------------
if [[ -f app/composer.json ]]; then
    log "app/ already contains a Composer project - keeping it"
else
    if [[ -d app && -n "$(ls -A app)" ]]; then
        die "app/ is not empty but has no composer.json - move it away and re-run"
    fi
    mkdir -p app
    log "Creating Bedrock project in app/"
    compose run --rm --no-deps composer create-project roots/bedrock . \
        --no-interaction --prefer-dist --no-progress
fi

# Bedrock moved from WPackagist (wpackagist-plugin/*) to WP Packages
# (wp-plugin/*); use whichever repository the project is configured with.
if grep -q 'wpackagist' app/composer.json; then
    redis_package=wpackagist-plugin/redis-cache
else
    redis_package=wp-plugin/redis-cache
fi
if grep -q "\"${redis_package}\"" app/composer.json; then
    log "Redis object cache plugin already required"
else
    log "Adding the Redis object cache plugin (${redis_package})"
    compose run --rm --no-deps composer require "$redis_package" \
        --no-interaction --no-progress
fi

compose run --rm --no-deps --entrypoint php composer /stack/configure.php /app

log "Done. Next: make up && make install"
