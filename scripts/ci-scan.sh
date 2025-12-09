#!/bin/bash
# CI/CD integration script

set -e

# Configuration
SCANNER_API="${SCANNER_API:-http://localhost:3000}"
FAIL_ON_CRITICAL="${FAIL_ON_CRITICAL:-true}"
FAIL_ON_HIGH="${FAIL_ON_HIGH:-false}"
MAX_WAIT="${MAX_WAIT:-300}"  # 5 minutes

# Get target from CI environment or default to current directory
TARGET="${CI_PROJECT_DIR:-$(pwd)}"

echo "============================================"
echo "  freesscan - CI Mode"
echo "============================================"
echo "Target: $TARGET"
echo "API: $SCANNER_API"
echo "Fail on CRITICAL: $FAIL_ON_CRITICAL"
echo "Fail on HIGH: $FAIL_ON_HIGH"
echo ""

# Start scan via API
echo "[*] Starting scan..."
RESPONSE=$(curl -s -X POST "$SCANNER_API/api/scans" \
    -H "Content-Type: application/json" \
    -d "{\"scan_type\": \"secret\", \"target\": \"$TARGET\"}" || echo "")

if [ -z "$RESPONSE" ]; then
    echo "[-] Failed to connect to scanner API"
    exit 1
fi

SCAN_ID=$(echo "$RESPONSE" | jq -r '.id' 2>/dev/null || echo "")

if [ -z "$SCAN_ID" ] || [ "$SCAN_ID" = "null" ]; then
    echo "[-] Failed to create scan"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "[+] Scan ID: $SCAN_ID"

# Poll for completion
ELAPSED=0
while true; do
    sleep 2
    ELAPSED=$((ELAPSED + 2))

    if [ $ELAPSED -gt $MAX_WAIT ]; then
        echo "[-] Scan timeout after ${MAX_WAIT}s"
        exit 1
    fi

    STATUS=$(curl -s "$SCANNER_API/api/scans/$SCAN_ID" | jq -r '.scan.status' 2>/dev/null || echo "unknown")

    if [ "$STATUS" = "completed" ]; then
        echo "[+] Scan completed (${ELAPSED}s)"
        break
    elif [ "$STATUS" = "failed" ]; then
        echo "[-] Scan failed"
        exit 1
    else
        echo "    Status: $STATUS (${ELAPSED}s)"
    fi
done

# Get results
RESULTS=$(curl -s "$SCANNER_API/api/scans/$SCAN_ID")

CRITICAL=$(echo "$RESULTS" | jq '[.findings[] | select(.severity_name == "CRITICAL" and .is_false_positive == false)] | length' 2>/dev/null || echo "0")
HIGH=$(echo "$RESULTS" | jq '[.findings[] | select(.severity_name == "HIGH" and .is_false_positive == false)] | length' 2>/dev/null || echo "0")
MEDIUM=$(echo "$RESULTS" | jq '[.findings[] | select(.severity_name == "MEDIUM" and .is_false_positive == false)] | length' 2>/dev/null || echo "0")
LOW=$(echo "$RESULTS" | jq '[.findings[] | select(.severity_name == "LOW" and .is_false_positive == false)] | length' 2>/dev/null || echo "0")

echo ""
echo "==========================="
echo "     SCAN RESULTS"
echo "==========================="
echo "  CRITICAL: $CRITICAL"
echo "  HIGH:     $HIGH"
echo "  MEDIUM:   $MEDIUM"
echo "  LOW:      $LOW"
echo "==========================="
echo ""

# Fail conditions
if [ "$FAIL_ON_CRITICAL" = "true" ] && [ "$CRITICAL" -gt 0 ]; then
    echo "[-] CRITICAL findings detected - failing build"
    exit 2
fi

if [ "$FAIL_ON_HIGH" = "true" ] && [ "$HIGH" -gt 0 ]; then
    echo "[-] HIGH findings detected - failing build"
    exit 1
fi

echo "[+] Security scan passed"
exit 0
