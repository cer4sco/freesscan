#!/bin/bash
# Database backup script

set -e

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-security_scanner}"
DB_USER="${DB_USER:-scanner}"
DB_PASSWORD="${DB_PASSWORD:-changeme}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "[*] Backing up database: $DB_NAME"
echo "[*] Backup file: $BACKUP_FILE"

PGPASSWORD="$DB_PASSWORD" pg_dump \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    --verbose \
    | gzip > "$BACKUP_FILE"

echo "[+] Backup completed: $(du -h "$BACKUP_FILE" | cut -f1)"

# Cleanup old backups (keep last 30 days)
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +30 -delete
echo "[+] Cleaned up old backups"
