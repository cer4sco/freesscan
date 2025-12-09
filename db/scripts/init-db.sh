#!/bin/bash
# Database initialization script for Security Scanner Security Scanner

set -e

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-security_scanner}"
DB_USER="${DB_USER:-scanner}"
DB_PASSWORD="${DB_PASSWORD:-changeme}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"

echo "[*] Initializing database: $DB_NAME"
echo "[*] Host: $DB_HOST:$DB_PORT"

# Wait for PostgreSQL to be ready
echo "[*] Waiting for PostgreSQL..."
until PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -c '\q' 2>/dev/null; do
    echo "    PostgreSQL not ready, waiting..."
    sleep 2
done
echo "[+] PostgreSQL is ready"

# Create database if not exists
echo "[*] Creating database..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -tc \
    "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -c \
    "CREATE DATABASE $DB_NAME"

# Create user if not exists
echo "[*] Creating user..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -tc \
    "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER'" | grep -q 1 || \
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -c \
    "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD'"

# Always update password (in case it changed)
echo "[*] Updating user password..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -c \
    "ALTER USER $DB_USER WITH PASSWORD '$DB_PASSWORD'"

# Grant privileges
echo "[*] Granting privileges..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -c \
    "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER"

# Grant schema permissions (required for PostgreSQL 15+)
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$DB_NAME" -c \
    "GRANT ALL ON SCHEMA public TO $DB_USER"

# Run schema
echo "[*] Running schema..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -f "$(dirname "$0")/../schema.sql"

# Run seed data
echo "[*] Running seed data..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -f "$(dirname "$0")/../seed.sql"

echo "[+] Database initialized successfully"
