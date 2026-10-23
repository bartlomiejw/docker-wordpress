#!/usr/bin/env bash
# Create a local TLS certificate for DOMAIN and *.DOMAIN in ./certs.
# Uses mkcert (trusted by your browser) when available, otherwise a
# self-signed certificate via openssl (accept the browser warning or curl -k).
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"

load_env
domain="${DOMAIN:?DOMAIN is not set}"
cert=certs/local.pem
key=certs/local-key.pem

mkdir -p certs

if command -v mkcert >/dev/null 2>&1; then
    log "Generating a locally trusted certificate with mkcert for ${domain}, *.${domain}"
    mkcert -install
    mkcert -cert-file "$cert" -key-file "$key" "$domain" "*.${domain}"
else
    warn "mkcert not found - generating a self-signed certificate with openssl"
    openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 825 \
        -keyout "$key" -out "$cert" \
        -subj "/CN=${domain}" \
        -addext "subjectAltName=DNS:${domain},DNS:*.${domain}" 2>/dev/null
fi

chmod 600 "$key"
log "Certificate written to ${cert}"
