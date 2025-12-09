#!/usr/bin/env python3
"""
freesscan
Main entry point for CLI usage
"""

import argparse
import sys
import os
from secret_scanner import SecretScanner
from port_scanner import PortScanner
from utils.reporter import Reporter


def main():
    parser = argparse.ArgumentParser(
        description='freesscan - Detect secrets and scan ports',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument(
        '--type',
        choices=['secret', 'port', 'full'],
        default='secret',
        help='Type of scan to perform (default: secret)'
    )

    parser.add_argument(
        '--target',
        required=True,
        help='Target to scan (file/directory for secrets, hostname/IP for ports)'
    )

    parser.add_argument(
        '--format',
        choices=['json', 'text', 'summary'],
        default='text',
        help='Output format (default: text)'
    )

    parser.add_argument(
        '--config',
        help='Path to custom configuration file'
    )

    parser.add_argument(
        '--scan-id',
        type=int,
        help='Scan ID for database integration'
    )

    parser.add_argument(
        '--port-range',
        help='Port range for port scanning (e.g., 1-1024)'
    )

    parser.add_argument(
        '--timeout',
        type=float,
        default=1.0,
        help='Timeout for port scanning (default: 1.0s)'
    )

    args = parser.parse_args()

    findings = []

    try:
        # Secret scanning
        if args.type in ['secret', 'full']:
            if not os.path.exists(args.target):
                print(f"Error: Target not found: {args.target}", file=sys.stderr)
                sys.exit(1)

            scanner = SecretScanner(config_path=args.config)
            secret_findings = scanner.scan(args.target)
            findings.extend(secret_findings)

        # Port scanning
        if args.type in ['port', 'full']:
            port_scanner = PortScanner(timeout=args.timeout)

            if args.port_range:
                # Parse port range
                try:
                    start, end = map(int, args.port_range.split('-'))
                    port_findings = port_scanner.scan_range(args.target, start, end)
                except ValueError:
                    print(f"Error: Invalid port range format: {args.port_range}", file=sys.stderr)
                    sys.exit(1)
            else:
                # Scan common ports
                port_findings = port_scanner.scan(args.target)

            findings.extend(port_findings)

        # Output results
        reporter = Reporter()

        if args.format == 'json':
            output = reporter.format_json(findings)
        elif args.format == 'summary':
            output = reporter.format_summary(findings)
        else:
            output = reporter.format_text(findings)

        print(output)

        # If database integration is requested, store findings
        if args.scan_id:
            store_findings_to_db(args.scan_id, findings)

        # Exit code based on findings severity
        has_critical = any(f.get('severity') == 'CRITICAL' for f in findings)
        has_high = any(f.get('severity') == 'HIGH' for f in findings)

        if has_critical:
            sys.exit(2)  # Critical findings
        elif has_high:
            sys.exit(1)  # High findings
        else:
            sys.exit(0)  # No critical/high findings

    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


def store_findings_to_db(scan_id: int, findings: list):
    """Store findings to database"""
    try:
        import psycopg2
        import os

        conn = psycopg2.connect(
            host=os.environ.get('DB_HOST', 'localhost'),
            port=os.environ.get('DB_PORT', '5432'),
            database=os.environ.get('DB_NAME', 'security_scanner'),
            user=os.environ.get('DB_USER', 'scanner'),
            password=os.environ.get('DB_PASSWORD')
        )

        cursor = conn.cursor()

        # Get severity IDs
        cursor.execute("SELECT id, name FROM severity_levels")
        severity_map = {name: id for id, name in cursor.fetchall()}

        # Insert findings
        for finding in findings:
            severity_id = severity_map.get(finding.get('severity', 'INFO'))

            cursor.execute(
                """
                INSERT INTO findings (
                    scan_id, severity_id, finding_type, title,
                    description, location, line_number, matched_content, remediation
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    scan_id,
                    severity_id,
                    finding.get('type'),
                    finding.get('description'),
                    finding.get('description'),
                    finding.get('file') or finding.get('location'),
                    finding.get('line'),
                    finding.get('match') or finding.get('banner'),
                    finding.get('remediation')
                )
            )

        # Update scan status
        cursor.execute(
            """
            UPDATE scans
            SET findings_count = %s, status = 'completed', completed_at = NOW()
            WHERE id = %s
            """,
            (len(findings), scan_id)
        )

        conn.commit()
        cursor.close()
        conn.close()

    except ImportError:
        print("Warning: psycopg2 not installed, skipping database storage", file=sys.stderr)
    except Exception as e:
        print(f"Warning: Database storage failed: {str(e)}", file=sys.stderr)


if __name__ == '__main__':
    main()
