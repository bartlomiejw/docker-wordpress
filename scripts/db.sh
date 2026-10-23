#!/usr/bin/env bash
# Database export/import through the running db container.
#   scripts/db.sh export [file.sql.gz]
#   scripts/db.sh import  file.sql[.gz]
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"

action="${1:-}"
file="${2:-}"

case "$action" in
    export)
        file="${file:-backups/db-$(date +%Y%m%d-%H%M%S).sql.gz}"
        mkdir -p "$(dirname "$file")"
        log "Exporting database to ${file}"
        # shellcheck disable=SC2016  # expanded inside the container
        compose exec -T db sh -c 'export MYSQL_PWD="$MARIADB_ROOT_PASSWORD"; exec mariadb-dump -uroot --single-transaction --quick --routines --triggers "$MARIADB_DATABASE"' \
            | gzip > "$file"
        ;;
    import)
        [[ -f "$file" ]] || die "Usage: $0 import <file.sql|file.sql.gz>"
        log "Importing ${file}"
        reader=(cat)
        [[ "$file" == *.gz ]] && reader=(gzip -dc)
        # shellcheck disable=SC2016  # expanded inside the container
        "${reader[@]}" "$file" \
            | compose exec -T db sh -c 'export MYSQL_PWD="$MARIADB_ROOT_PASSWORD"; exec mariadb -uroot "$MARIADB_DATABASE"'
        ;;
    *)
        die "Usage: $0 export [file] | import <file>"
        ;;
esac
