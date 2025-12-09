#!/bin/bash
# Ingest scanner output to database

set -e

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-security_scanner}"
DB_USER="${DB_USER:-scanner}"
DB_PASSWORD="${DB_PASSWORD:-changeme}"

SCAN_TYPE="${1:-secret}"
TARGET="${2:-.}"
CREATED_BY="${3:-cli}"

echo "[*] Creating scan record..."

# Create scan record and get ID using parameterized query
SCAN_ID=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -v scan_type="$SCAN_TYPE" -v target="$TARGET" -v created_by="$CREATED_BY" <<'SQL'
INSERT INTO scans (scan_type, target, status, created_by)
VALUES (:'scan_type', :'target', 'running', :'created_by')
RETURNING id;
SQL
)

SCAN_ID=$(echo "$SCAN_ID" | xargs)

echo "[+] Scan ID: $SCAN_ID"
echo "[*] Running scanner..."

# Run scanner with database integration
python3 "$(dirname "$0")/../../scanner/main.py" \
    --type "$SCAN_TYPE" \
    --target "$TARGET" \
    --scan-id "$SCAN_ID" \
    --format summary

echo "[+] Scan complete"
