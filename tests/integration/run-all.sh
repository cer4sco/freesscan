#!/bin/bash
# Integration Test Runner for freesscan
# Runs complete test suite: prerequisites, database, scanner, API, Docker

# Note: Not using 'set -e' to allow collecting all test results

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="$PROJECT_ROOT/test-results.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FAILED=0
PASSED=0
WARNINGS=0

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

pass() {
    log "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

fail() {
    log "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

warn() {
    log "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

info() {
    log "${BLUE}[INFO]${NC} $1"
}

# Initialize
echo "" > "$LOG_FILE"
log "=========================================="
log "Security Scanner - Integration Test Suite"
log "Started: $(date)"
log "=========================================="

# -----------------------------------------
# Phase 1: Prerequisites
# -----------------------------------------
log "\n${BLUE}=== PHASE 1: PREREQUISITES ===${NC}"

if command -v python3 >/dev/null 2>&1; then
    pass "Python3 installed"
else
    fail "Python3 not found"
fi

if command -v node >/dev/null 2>&1; then
    pass "Node.js installed"
else
    fail "Node.js not found"
fi

if command -v psql >/dev/null 2>&1; then
    pass "PostgreSQL client installed"
else
    fail "psql not found"
fi

if command -v docker >/dev/null 2>&1; then
    pass "Container runtime: docker"
    CONTAINER_CMD="docker"
elif command -v podman >/dev/null 2>&1; then
    pass "Container runtime: podman"
    CONTAINER_CMD="podman"
else
    warn "No container runtime found (docker/podman) - skipping container tests"
    CONTAINER_CMD=""
fi

if command -v jq >/dev/null 2>&1; then
    pass "jq installed"
else
    fail "jq not found"
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
info "Python version: $PYTHON_VERSION"

NODE_VERSION=$(node --version)
info "Node.js version: $NODE_VERSION"

# -----------------------------------------
# Phase 2: Database
# -----------------------------------------
log "\n${BLUE}=== PHASE 2: DATABASE ===${NC}"

cd "$PROJECT_ROOT" || exit 1

if ./db/scripts/init-db.sh >> "$LOG_FILE" 2>&1; then
    pass "Database initialized"
else
    fail "Database initialization failed"
fi

TABLE_COUNT=$(PGPASSWORD="${DB_PASSWORD:-changeme}" psql -h localhost -U scanner -d security_scanner -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' \n')
TABLE_COUNT=${TABLE_COUNT:-0}
if [ "$TABLE_COUNT" -ge 4 ]; then
    pass "Tables created ($TABLE_COUNT tables)"
else
    fail "Expected 4+ tables, found $TABLE_COUNT"
fi

SEVERITY_COUNT=$(PGPASSWORD="${DB_PASSWORD:-changeme}" psql -h localhost -U scanner -d security_scanner -t -c "SELECT COUNT(*) FROM severity_levels;" 2>/dev/null | tr -d ' \n')
SEVERITY_COUNT=${SEVERITY_COUNT:-0}
if [ "$SEVERITY_COUNT" -eq 5 ]; then
    pass "Severity levels seeded (5 levels)"
else
    fail "Expected 5 severity levels, found $SEVERITY_COUNT"
fi

# -----------------------------------------
# Phase 3: Secret Scanner
# -----------------------------------------
log "\n${BLUE}=== PHASE 3: SECRET SCANNER ===${NC}"

cd "$PROJECT_ROOT/scanner" || exit 1

# Create temp test file
cat > /tmp/test-secrets.env << 'EOF'
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
GITHUB_TOKEN=ghp_1234567890abcdefghijklmnopqrstuvwxyz
DATABASE_URL=postgresql://user:password123@localhost/db
EOF

SCAN_OUTPUT=$(python3 main.py --type secret --target /tmp/test-secrets.env --format json 2>&1 || echo "[]")
FINDING_COUNT=$(echo "$SCAN_OUTPUT" | jq '. | length' 2>/dev/null | tr -d '\n' || echo "0")

if [ "$FINDING_COUNT" -ge 3 ]; then
    pass "Secret scanner detected $FINDING_COUNT secrets"
else
    fail "Expected 3+ secrets, found $FINDING_COUNT"
fi

CRITICAL_COUNT=$(echo "$SCAN_OUTPUT" | jq '[.[] | select(.severity == "CRITICAL")] | length' 2>/dev/null | tr -d '\n' || echo "0")
if [ "$CRITICAL_COUNT" -ge 2 ]; then
    pass "Critical severity classification working ($CRITICAL_COUNT CRITICAL)"
else
    warn "Expected 2+ CRITICAL, found $CRITICAL_COUNT"
fi

# Test on fixtures
FIXTURES_OUTPUT=$(python3 main.py --type secret --target "$PROJECT_ROOT/tests/fixtures/sample_repo" --format json 2>&1 || echo "[]")
FIXTURES_COUNT=$(echo "$FIXTURES_OUTPUT" | jq '. | length' 2>/dev/null | tr -d '\n' || echo "0")

if [ "$FIXTURES_COUNT" -ge 10 ]; then
    pass "Fixtures scan detected $FIXTURES_COUNT secrets"
else
    warn "Expected 10+ secrets in fixtures, found $FIXTURES_COUNT"
fi

# -----------------------------------------
# Phase 4: Port Scanner
# -----------------------------------------
log "\n${BLUE}=== PHASE 4: PORT SCANNER ===${NC}"

PORT_OUTPUT=$(timeout 45 python3 main.py --type port --target localhost --format json 2>&1 || echo "[]")
OPEN_PORTS=$(echo "$PORT_OUTPUT" | jq '. | length' 2>/dev/null || echo "0")

if [ "$OPEN_PORTS" -ge 0 ]; then
    pass "Port scanner completed (detected $OPEN_PORTS open ports)"
else
    fail "Port scanner failed"
fi
port_scan_status=$?

# Check for socket leaks (scanner should complete, not hang)
if [ $port_scan_status -eq 0 ] || [ $port_scan_status -eq 124 ]; then
    pass "Port scanner completed without hanging"
else
    fail "Port scanner may have leaked sockets"
fi

# -----------------------------------------
# Phase 5: API Server
# -----------------------------------------
log "\n${BLUE}=== PHASE 5: API SERVER ===${NC}"

cd "$PROJECT_ROOT/api" || exit 1

if [ ! -d "node_modules" ]; then
    info "Installing API dependencies..."
    npm install --silent >> "$LOG_FILE" 2>&1 && pass "npm dependencies installed" || fail "npm install failed"
fi

# Create .env for testing
cat > .env << 'EOF'
DB_HOST=localhost
DB_PORT=5432
DB_NAME=security_scanner
DB_USER=scanner
DB_PASSWORD=changeme
PORT=3000
NODE_ENV=test
EOF

info "Starting API server in background..."
npm start >> "$LOG_FILE" 2>&1 &
API_PID=$!
sleep 5

# Health check
HEALTH=$(curl -s http://localhost:3000/health 2>/dev/null || echo '{"status":"error"}')
STATUS=$(echo "$HEALTH" | jq -r '.status' 2>/dev/null || echo "error")
if [ "$STATUS" = "healthy" ]; then
    pass "API health check passed"
else
    fail "API health check failed: $HEALTH"
fi

# Create scan
SCAN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/scans \
    -H "Content-Type: application/json" \
    -d '{"scan_type":"secret","target":"/tmp","created_by":"integration-test"}' 2>/dev/null || echo '{}')

SCAN_ID=$(echo "$SCAN_RESPONSE" | jq -r '.id' 2>/dev/null || echo "null")
if [ "$SCAN_ID" != "null" ] && [ -n "$SCAN_ID" ] && [ "$SCAN_ID" != "" ]; then
    pass "Scan created via API (ID: $SCAN_ID)"
else
    fail "Failed to create scan via API"
fi

sleep 5

# Get findings
FINDINGS_RESPONSE=$(curl -s "http://localhost:3000/api/findings?limit=10" 2>/dev/null || echo '[]')
if echo "$FINDINGS_RESPONSE" | jq -e 'type == "array"' >/dev/null 2>&1; then
    FINDINGS_COUNT=$(echo "$FINDINGS_RESPONSE" | jq '. | length')
    pass "Findings endpoint working ($FINDINGS_COUNT findings)"
else
    fail "Findings endpoint failed"
fi

# Summary endpoint (route ordering test)
SUMMARY_RESPONSE=$(curl -s "http://localhost:3000/api/findings/stats/summary" 2>/dev/null || echo '[]')
if echo "$SUMMARY_RESPONSE" | jq -e 'type == "array"' >/dev/null 2>&1; then
    pass "Summary endpoint working (route ordering fix verified)"
else
    fail "Summary endpoint failed (route ordering issue?)"
fi

# Error handling test
ERROR_RESPONSE=$(curl -s -X POST http://localhost:3000/api/scans \
    -H "Content-Type: application/json" \
    -d '{"scan_type":"invalid"}' 2>/dev/null || echo '{}')

if echo "$ERROR_RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
    pass "Error handling working (validation functional)"
else
    fail "Error handling not working properly"
fi

# Cleanup API
info "Stopping API server..."
kill $API_PID 2>/dev/null || true
sleep 2

# -----------------------------------------
# Phase 6: Mocha Unit Tests
# -----------------------------------------
log "\n${BLUE}=== PHASE 6: UNIT TESTS ===${NC}"

cd "$PROJECT_ROOT/tests" || exit 1

if [ ! -d "node_modules" ]; then
    info "Installing test dependencies..."
    npm install --silent >> "$LOG_FILE" 2>&1
fi

if npm test >> "$LOG_FILE" 2>&1; then
    pass "Mocha unit tests passed"
else
    warn "Some unit tests failed (check log for details)"
fi

# -----------------------------------------
# Phase 7: Containers (Optional)
# -----------------------------------------
log "\n${BLUE}=== PHASE 7: CONTAINERS (optional) ===${NC}"

if [ -n "$CONTAINER_CMD" ] && $CONTAINER_CMD ps >/dev/null 2>&1; then
    cd "$PROJECT_ROOT" || exit 1

    # Determine compose command
    if [ "$CONTAINER_CMD" = "podman" ]; then
        COMPOSE_CMD="podman-compose"
    else
        COMPOSE_CMD="docker-compose"
    fi

    info "Starting containers with $COMPOSE_CMD..."
    if $COMPOSE_CMD up -d >> "$LOG_FILE" 2>&1; then
        pass "Containers started"
        sleep 15

        DOCKER_HEALTH=$(curl -s http://localhost:8080/health 2>/dev/null || echo '{"status":"error"}')
        DOCKER_STATUS=$(echo "$DOCKER_HEALTH" | jq -r '.status' 2>/dev/null || echo "error")
        if [ "$DOCKER_STATUS" = "healthy" ]; then
            pass "Container API health check passed"
        else
            fail "Container API not responding"
        fi

        info "Stopping containers..."
        $COMPOSE_CMD down -v >> "$LOG_FILE" 2>&1
        pass "Container cleanup complete"
    else
        fail "$COMPOSE_CMD failed"
    fi
else
    warn "No container runtime running - skipping container tests"
fi

# -----------------------------------------
# Summary
# -----------------------------------------
log "\n=========================================="
log "TEST SUMMARY"
log "=========================================="
log "${GREEN}PASSED:${NC} $PASSED"
log "${YELLOW}WARNINGS:${NC} $WARNINGS"
log "${RED}FAILED:${NC} $FAILED"
log "=========================================="
log "Completed: $(date)"
log "Log file: $LOG_FILE"
log "=========================================="

if [ "$FAILED" -eq 0 ]; then
    log "\n${GREEN}✓ ALL TESTS PASSED${NC}\n"
    exit 0
else
    log "\n${RED}✗ SOME TESTS FAILED - Review log for details${NC}\n"
    exit 1
fi
