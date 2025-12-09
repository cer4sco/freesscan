#!/bin/bash
# Run security scan

set -e

SCAN_TYPE="${1:-secret}"
TARGET="${2:-.}"
OUTPUT_FORMAT="${3:-json}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNER_DIR="$(dirname "$SCRIPT_DIR")/scanner"

echo "[*] Starting ${SCAN_TYPE} scan on ${TARGET}"

# Run Python scanner
python3 "$SCANNER_DIR/main.py" \
    --type "$SCAN_TYPE" \
    --target "$TARGET" \
    --format "$OUTPUT_FORMAT"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "[+] Scan completed successfully"
elif [ $EXIT_CODE -eq 1 ]; then
    echo "[!] Scan completed with HIGH severity findings"
elif [ $EXIT_CODE -eq 2 ]; then
    echo "[!] Scan completed with CRITICAL severity findings"
else
    echo "[-] Scan failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE
