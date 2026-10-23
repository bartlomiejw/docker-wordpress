#!/usr/bin/env bash
# End-to-end check of a running local stack (used by CI and `make smoke`).
# Requires: make init && make up
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"

load_env
domain="${DOMAIN:?}"
http_port="${HTTP_PORT:-80}"
https_port="${HTTPS_PORT:-443}"
failures=0

site="https://${domain}:${https_port}"
dashboard="https://traefik.${domain}:${https_port}"
mailpit="https://mail.${domain}:${https_port}"

# Resolve every hostname to the local Traefik regardless of the system resolver.
curl_() {
    curl -ksS --max-time 20 \
        --resolve "${domain}:${https_port}:127.0.0.1" \
        --resolve "${domain}:${http_port}:127.0.0.1" \
        --resolve "traefik.${domain}:${https_port}:127.0.0.1" \
        --resolve "mail.${domain}:${https_port}:127.0.0.1" \
        "$@"
}

check() {
    local name=$1 expected=$2 actual=$3
    if [[ "$actual" == "$expected" ]]; then
        printf '  ok    %-48s %s\n' "$name" "$actual"
    else
        printf '  FAIL  %-48s expected %s, got %s\n' "$name" "$expected" "$actual"
        failures=$((failures + 1))
    fi
}

yesno() { if "$@"; then echo yes; else echo no; fi; }
status() { curl_ -o /dev/null -w '%{http_code}' "$@"; }
header() { curl_ -o /dev/null -D - "${@:2}" | tr -d '\r' | awk -v h="$1" 'tolower($1) == tolower(h) ":" { print $2 }' | tail -n1; }

log "Waiting for ${site} to answer through Traefik"
for _ in $(seq 1 60); do
    code="$(status "${site}/wp/wp-login.php" || true)"
    [[ "$code" =~ ^(200|302)$ ]] && break
    sleep 2
done

log "Edge"
check "HTTP redirects to HTTPS" "301" "$(status "http://${domain}:${http_port}/")"
check "Redirect target" "${site}/" "$(header Location "http://${domain}:${http_port}/")"
check "Dashboard requires auth" "401" "$(status "${dashboard}/dashboard/")"
check "Dashboard with credentials" "200" \
    "$(status -u "admin:${TRAEFIK_DASHBOARD_PASSWORD}" "${dashboard}/dashboard/")"
check "PURGE refused at the edge" "404" "$(status -X PURGE "${site}/")"

log "WordPress"
if ! wp core is-installed >/dev/null 2>&1; then
    check "Install page reachable" "200" "$(status -L "${site}/")"
    check "Install page content" "yes" \
        "$(yesno grep -q 'Installation' <<< "$(curl_ -L "${site}/")")"
    "$ROOT_DIR/scripts/install-wordpress.sh" >/dev/null
fi
check "Redis object cache" "Connected" "$(wp redis status | awk -F': ' '/^Status/ { print $2 }')"

log "Varnish"
compose exec -T varnish varnishadm 'ban req.url ~ .' >/dev/null
check "Front page" "200" "$(status "${site}/")"
check "Second request served from cache" "HIT" "$(header X-Cache "${site}/")"
check "Admin bypasses cache" "PASS" "$(header X-Cache "${site}/wp/wp-login.php")"
check "Logged-in cookie bypasses cache" "PASS" \
    "$(header X-Cache -H 'Cookie: wordpress_logged_in_x=y' "${site}/")"
check "Security header (X-Content-Type-Options)" "nosniff" \
    "$(header X-Content-Type-Options "${site}/")"

log "Mail"
wp eval 'wp_mail("smoke@example.test", "Smoke test", "It works.");' >/dev/null
check "Mailpit received the message" "yes" \
    "$(yesno grep -q '"messages_count":[1-9]' <<< "$(curl_ "${mailpit}/api/v1/search?query=subject:%22Smoke%20test%22")")"

if (( failures > 0 )); then
    die "${failures} check(s) failed"
fi
log "All checks passed"
