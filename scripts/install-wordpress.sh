#!/usr/bin/env bash
# Install WordPress (if needed) and enable the Redis object cache.
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"

load_env
home="${WP_HOME:-https://${DOMAIN}}"

if wp core is-installed >/dev/null 2>&1; then
    log "WordPress is already installed"
else
    log "Installing WordPress at ${home}"
    wp core install \
        --url="${home}" \
        --title="${WP_TITLE:-WordPress}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email
    wp rewrite structure '/%postname%/'
fi

log "Enabling the Redis object cache"
wp plugin activate redis-cache
if ! wp redis status | grep -q 'Drop-in: Valid'; then
    wp redis enable
fi

log "Admin: ${home}/wp/wp-admin (user: ${WP_ADMIN_USER}, password in .env)"
