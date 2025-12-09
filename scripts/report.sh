#!/bin/bash
# Generate scan reports

set -e

SCANNER_API="${SCANNER_API:-http://localhost:3000}"
SCAN_ID="${1}"
REPORT_FORMAT="${2:-text}"
OUTPUT_FILE="${3}"

if [ -z "$SCAN_ID" ]; then
    echo "Usage: $0 <scan_id> [format] [output_file]"
    echo "  format: text, json, html (default: text)"
    exit 1
fi

echo "[*] Generating report for scan #$SCAN_ID"

# Fetch scan data
SCAN_DATA=$(curl -s "$SCANNER_API/api/scans/$SCAN_ID")

if [ -z "$SCAN_DATA" ]; then
    echo "[-] Failed to fetch scan data"
    exit 1
fi

# Generate report based on format
if [ "$REPORT_FORMAT" = "json" ]; then
    REPORT="$SCAN_DATA"
elif [ "$REPORT_FORMAT" = "html" ]; then
    # Simple HTML report
    SCAN_INFO=$(echo "$SCAN_DATA" | jq -r '.scan')
    FINDINGS=$(echo "$SCAN_DATA" | jq -r '.findings')

    REPORT="<!DOCTYPE html>
<html>
<head>
    <title>Security Scan Report #$SCAN_ID</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        .critical { color: #d32f2f; font-weight: bold; }
        .high { color: #f57c00; font-weight: bold; }
        .medium { color: #fbc02d; }
        .low { color: #388e3c; }
    </style>
</head>
<body>
    <h1>Security Scan Report</h1>
    <p>Scan ID: $SCAN_ID</p>
    <p>Target: $(echo "$SCAN_INFO" | jq -r '.target')</p>
    <p>Status: $(echo "$SCAN_INFO" | jq -r '.status')</p>
    <p>Findings: $(echo "$SCAN_INFO" | jq -r '.findings_count')</p>

    <h2>Findings</h2>
    <table>
        <tr>
            <th>Severity</th>
            <th>Type</th>
            <th>Location</th>
            <th>Description</th>
        </tr>"

    echo "$FINDINGS" | jq -c '.[]' | while read -r finding; do
        SEVERITY=$(echo "$finding" | jq -r '.severity_name')
        TYPE=$(echo "$finding" | jq -r '.finding_type')
        LOCATION=$(echo "$finding" | jq -r '.location')
        DESC=$(echo "$finding" | jq -r '.description')

        REPORT="$REPORT
        <tr>
            <td class=\"${SEVERITY,,}\">$SEVERITY</td>
            <td>$TYPE</td>
            <td>$LOCATION</td>
            <td>$DESC</td>
        </tr>"
    done

    REPORT="$REPORT
    </table>
</body>
</html>"
else
    # Text format
    REPORT=$(echo "$SCAN_DATA" | jq -r '
        "Scan Report #" + (.scan.id | tostring) + "\n" +
        "Target: " + .scan.target + "\n" +
        "Status: " + .scan.status + "\n" +
        "Findings: " + (.scan.findings_count | tostring) + "\n\n" +
        (.findings[] |
            "---\n" +
            "Severity: " + .severity_name + "\n" +
            "Type: " + .finding_type + "\n" +
            "Location: " + .location + "\n" +
            "Description: " + .description + "\n"
        )
    ')
fi

# Output report
if [ -n "$OUTPUT_FILE" ]; then
    echo "$REPORT" > "$OUTPUT_FILE"
    echo "[+] Report saved to: $OUTPUT_FILE"
else
    echo "$REPORT"
fi
