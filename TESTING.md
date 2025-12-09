# Testing Guide

Complete testing instructions for new contributors or users forking this project.

**Note:** These instructions use Podman. If you use Docker, replace `podman-compose` with `docker-compose`.

---

## Prerequisites

### Required Software

```bash
# Verify you have everything installed:
python3 --version    # Should be 3.9+
node --version       # Should be 18+
npm --version
psql --version       # PostgreSQL client
podman --version
```

### macOS Setup

```bash
# Install PostgreSQL client (for psql command)
brew install libpq

# Add to PATH permanently
echo 'export PATH="/opt/homebrew/opt/libpq/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Verify psql is available
which psql  # Should show /opt/homebrew/opt/libpq/bin/psql
```

### Linux Setup

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y postgresql-client python3 python3-pip nodejs npm

# Fedora/RHEL
sudo dnf install -y postgresql python3 nodejs npm
```

---

## Fresh Fork Test (Complete Workflow)

### 1. Clone and Setup

```bash
# Clone your fork and navigate to project root
cd PROJECT_ROOT

# Install Node dependencies for tests
cd tests
npm install
cd ..

# Install Node dependencies for API
cd api
npm install
cd ..
```

### 2. Start PostgreSQL Database

```bash
# Start PostgreSQL container
podman-compose up -d freesscan-db

# Wait for PostgreSQL to be ready
sleep 5

# Verify database is running
podman ps | grep freesscan-db
```

### 3. Initialize Database

**Database credentials (used throughout):**

- Host: `localhost`
- Port: `5432`
- Database: `freesscan`
- User: `scanner`
- Password: `changeme`

```bash
# macOS: Ensure libpq is in PATH
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# Initialize database schema
PGPASSWORD=changeme psql \
  -h localhost \
  -p 5432 \
  -U scanner \
  -d freesscan \
  -f db/schema.sql

# Seed test data
PGPASSWORD=changeme psql \
  -h localhost \
  -p 5432 \
  -U scanner \
  -d freesscan \
  -f db/seed.sql

# Verify tables created
PGPASSWORD=changeme psql \
  -h localhost \
  -p 5432 \
  -U scanner \
  -d freesscan \
  -c "\dt"
```

### 4. Run Unit Tests

```bash
cd tests

# Run all tests (API + Scanner)
npm test

# Expected output:
#   50 passing (1-2s)

# Run just API tests
npm run test:api

# Expected output:
#   26 passing

# Run just scanner tests
npm run test:scanner

# Expected output:
#   24 passing
```

### 5. Run Integration Tests

```bash
# Return to project root
cd ..

# macOS: Set environment variables
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export DB_PASSWORD=changeme

# Run full integration test suite
./tests/integration/run-all.sh

# Expected phases to pass:
#   Phase 1: Prerequisites
#   Phase 2: Database
#   Phase 3: Secret Scanner
#   Phase 4: Port Scanner
#   Phase 5: API Server
#   Phase 6: Unit Tests (50/50)
#   Phase 7: Containers (optional)
#
# Result: 19-20 PASSED, 0-1 FAILED (container tests might vary)
```

### 6. Test Container Builds (Optional)

```bash
# Clean previous builds
podman-compose down -v
podman rmi localhost/security-scanner_freesscan-api localhost/security-scanner_freesscan-worker 2>/dev/null || true

# Build fresh containers
podman-compose build --no-cache

# Verify builds succeeded
podman images | grep freesscan

# Start all services
podman-compose up -d

# Check all containers are running
podman-compose ps

# Test API endpoint
curl http://localhost:8080/health

# Expected output:
# {"status":"healthy","timestamp":"...","database":{"connected":true,"server_time":"..."}}

# Stop containers
podman-compose down
```

---

## Quick Test (Just Unit Tests)

If you only want to verify unit tests work:

```bash
# 1. Start database
podman-compose up -d freesscan-db
sleep 5

# 2. Initialize schema
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"  # macOS only
PGPASSWORD=changeme psql -h localhost -p 5432 -U scanner -d freesscan -f db/schema.sql
PGPASSWORD=changeme psql -h localhost -p 5432 -U scanner -d freesscan -f db/seed.sql

# 3. Run tests
cd tests && npm install && npm test
```

---

## Troubleshooting

### Port 8080 Already in Use

```bash
# Kill process using port 8080
lsof -ti:8080 | xargs kill -9

# Or kill any node servers
pkill -9 -f "node.*server"
```

### PostgreSQL Not Ready

```bash
# Check PostgreSQL logs
podman logs freesscan-db

# Restart PostgreSQL
podman-compose restart freesscan-db
sleep 5
```

### psql Command Not Found (macOS)

```bash
# Install libpq
brew install libpq

# Add to PATH
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# Make permanent
echo 'export PATH="/opt/homebrew/opt/libpq/bin:$PATH"' >> ~/.zshrc
```

### Scanner Tests Failing

```bash
# Verify Python version
python3 --version  # Should be 3.9+

# Test scanner manually
python3 scanner/main.py \
  --type secret \
  --target tests/fixtures/sample_repo \
  --format json

# Should output JSON array of findings
```

### Container Build Fails

Container builds are tested and working. If you encounter issues:

```bash
# Clean everything
podman-compose down -v
podman system prune -f

# Rebuild
podman-compose build --no-cache
podman-compose up -d
```

---

## CI/CD Testing

To verify CI/CD integration (scanner exits with non-zero on findings):

```bash
# Scanner should exit 2 when CRITICAL secrets found
python3 scanner/main.py \
  --type secret \
  --target tests/fixtures/sample_repo/aws_credentials.env \
  --format json

echo $?  # Should be 2 (CRITICAL severity)

# Scanner should exit 1 when HIGH secrets found (no CRITICAL)
# Scanner should exit 0 when no secrets found
```

---

## Performance Benchmarks

Expected test execution times:

| Test Suite | Tests | Duration |
| ---------- | ----- | -------- |
| Unit Tests (all) | 50 | 1-2s |
| API Tests | 26 | 200-400ms |
| Scanner Tests | 24 | 1.2-1.8s |
| Integration Tests | 19 phases | 20-30s |
| Container Build | - | 30-60s |

**Total fresh test run:** ~2-3 minutes

---

## Cleanup

```bash
# Stop all containers
podman-compose down -v

# Remove built images
podman rmi localhost/security-scanner_freesscan-api localhost/security-scanner_freesscan-worker

# Kill any stuck processes
pkill -9 -f "node.*server"
lsof -ti:8080 | xargs kill -9 2>/dev/null || true

# Clear test database
podman volume rm security-scanner_freesscan-db-data 2>/dev/null || true
```

---

## Success Criteria

- All 50 unit tests pass
- Integration test shows 19-20 PASSED
- API health endpoint returns 200
- Scanner detects secrets with correct exit codes
- Container builds complete successfully

If all criteria met: **Project is working correctly!**
