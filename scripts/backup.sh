#!/usr/bin/env bash
# Backup / restore the database and uploads.
#   scripts/backup.sh create             -> backups/<timestamp>/{db.sql.gz,uploads.tar.gz}
#   scripts/backup.sh restore <dir>
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"

uploads_parent=/var/www/html/web/app

case "${1:-}" in
    create)
        dest="backups/$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$dest"
        "$ROOT_DIR/scripts/db.sh" export "$dest/db.sql.gz"
        log "Archiving uploads"
        compose exec -T php sh -c "mkdir -p ${uploads_parent}/uploads && tar -C ${uploads_parent} -czf - uploads" \
            > "$dest/uploads.tar.gz"
        log "Backup written to ${dest}"
        ;;
    restore)
        src="${2:-}"
        [[ -f "$src/db.sql.gz" && -f "$src/uploads.tar.gz" ]] || die "Usage: $0 restore backups/<timestamp>"
        "$ROOT_DIR/scripts/db.sh" import "$src/db.sql.gz"
        log "Restoring uploads"
        compose exec -T -u www-data php sh -c "rm -rf ${uploads_parent}/uploads && tar -C ${uploads_parent} -xzf -" \
            < "$src/uploads.tar.gz"
        log "Flushing caches"
        wp cache flush || true
        compose exec -T varnish varnishadm 'ban req.url ~ .' || true
        ;;
    *)
        die "Usage: $0 create | restore <dir>"
        ;;
esac
