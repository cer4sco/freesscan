#!/bin/bash
# Setup test environment with user-provided credentials

echo "=== Security Scanner Test Environment Setup ==="
echo ""
echo "Enter database credentials for this test session:"
echo ""

# Prompt for user
echo -n "Database User [scanner]: "
read DB_USER
DB_USER=${DB_USER:-scanner}

# Prompt for password (hidden)
echo -n "Database Password: "
read -s DB_PASSWORD
echo ""

# Prompt for database name
echo -n "Database Name [security_scanner]: "
read DB_NAME
DB_NAME=${DB_NAME:-security_scanner}

echo ""
echo "Credentials set. Restarting database with new credentials..."
echo ""

# Export for podman-compose and psql
export DB_USER
export DB_PASSWORD
export DB_NAME
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# Stop and remove existing containers
echo "Stopping existing containers..."
podman-compose down -v 2>/dev/null || true

# Start fresh database with YOUR credentials
echo "Starting database with your credentials..."
podman-compose up -d scanner-db

echo "Waiting for database to be ready..."
sleep 5

# Initialize database
echo "Initializing database schema..."
PGPASSWORD=$DB_PASSWORD psql -h localhost -p 5432 -U $DB_USER -d $DB_NAME -f db/schema.sql

echo "Seeding test data..."
PGPASSWORD=$DB_PASSWORD psql -h localhost -p 5432 -U $DB_USER -d $DB_NAME -f db/seed.sql

echo ""
echo "✓ Environment ready!"
echo "✓ Database running with your credentials"
echo ""
echo "Run tests with: cd tests && npm test"
