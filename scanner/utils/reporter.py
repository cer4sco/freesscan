"""Output formatting and reporting"""

import json
from typing import List, Dict
from datetime import datetime


class Reporter:
    """Format and output scan findings"""

    @staticmethod
    def format_json(findings: List[Dict]) -> str:
        """Format findings as JSON"""
        return json.dumps(findings, indent=2)

    @staticmethod
    def format_text(findings: List[Dict]) -> str:
        """Format findings as human-readable text"""
        if not findings:
            return "No findings detected."

        output = []
        output.append(f"Security Scan Results - {datetime.now().isoformat()}")
        output.append("=" * 60)
        output.append(f"Total findings: {len(findings)}\n")

        # Group by severity
        severity_counts = {}
        for finding in findings:
            severity = finding.get('severity', 'UNKNOWN')
            severity_counts[severity] = severity_counts.get(severity, 0) + 1

        # Summary
        output.append("Summary by Severity:")
        for severity in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO']:
            if severity in severity_counts:
                output.append(f"  {severity}: {severity_counts[severity]}")

        output.append("\n" + "=" * 60 + "\n")

        # Detailed findings
        for idx, finding in enumerate(findings, 1):
            output.append(f"Finding #{idx}")
            output.append(f"  Severity: {finding.get('severity', 'UNKNOWN')}")
            output.append(f"  Type: {finding.get('type', 'unknown')}")
            output.append(f"  Location: {finding.get('file', 'N/A')}:{finding.get('line', 0)}")
            output.append(f"  Description: {finding.get('description', 'N/A')}")
            if finding.get('match'):
                output.append(f"  Match: {finding['match']}")
            if finding.get('remediation'):
                output.append(f"  Remediation: {finding['remediation']}")
            output.append("")

        return "\n".join(output)

    @staticmethod
    def format_summary(findings: List[Dict]) -> str:
        """Format findings as summary statistics"""
        severity_counts = {}
        type_counts = {}

        for finding in findings:
            severity = finding.get('severity', 'UNKNOWN')
            finding_type = finding.get('type', 'unknown')

            severity_counts[severity] = severity_counts.get(severity, 0) + 1
            type_counts[finding_type] = type_counts.get(finding_type, 0) + 1

        output = []
        output.append("SCAN SUMMARY")
        output.append("=" * 40)
        output.append(f"Total Findings: {len(findings)}")
        output.append("\nBy Severity:")
        for severity in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO']:
            if severity in severity_counts:
                output.append(f"  {severity}: {severity_counts[severity]}")

        output.append("\nTop Finding Types:")
        sorted_types = sorted(type_counts.items(), key=lambda x: x[1], reverse=True)
        for finding_type, count in sorted_types[:10]:
            output.append(f"  {finding_type}: {count}")

        return "\n".join(output)
