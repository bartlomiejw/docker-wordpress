#!/usr/bin/env bash
# Shared helpers, sourced by the other scripts.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

# The Makefile passes the full compose command (local or production files).
read -r -a COMPOSE_CMD <<< "${COMPOSE:-docker compose}"

# Containers that write to bind mounts run with the host user's IDs.
HOST_UID="${HOST_UID:-$(id -u)}"
HOST_GID="${HOST_GID:-$(id -g)}"
export HOST_UID HOST_GID

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

compose() { "${COMPOSE_CMD[@]}" "$@"; }

# Run wp-cli in a one-off container (no TTY, safe for CI and pipes).
wp() { compose --progress quiet run --rm -T wp-cli "$@"; }

load_env() {
    [[ -f .env ]] || die ".env not found - run 'make init' first"
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
}
