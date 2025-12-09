"""Secret scanner for detecting hardcoded credentials"""

import re
import os
from typing import List, Dict, Generator
from patterns.aws import AWS_PATTERNS
from patterns.generic import GENERIC_PATTERNS
from patterns.cloud import CLOUD_PATTERNS
from utils.file_handler import FileHandler


class SecretScanner:
    """Scan files for hardcoded secrets and credentials"""

    def __init__(self, config_path: str = None):
        self.patterns = self._load_patterns(config_path)
        self.file_handler = FileHandler()

    def _load_patterns(self, config_path: str) -> List[Dict]:
        """Load regex patterns from config or defaults"""
        patterns = []
        patterns.extend(AWS_PATTERNS)
        patterns.extend(GENERIC_PATTERNS)
        patterns.extend(CLOUD_PATTERNS)

        if config_path and os.path.exists(config_path):
            import json
            with open(config_path, 'r') as f:
                custom = json.load(f)
                patterns.extend(custom.get('patterns', []))

        return patterns

    def scan_file(self, filepath: str) -> Generator[Dict, None, None]:
        """Scan single file for secrets"""
        try:
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                for line_num, line in enumerate(f, 1):
                    for pattern in self.patterns:
                        try:
                            matches = re.finditer(pattern['regex'], line)
                            for match in matches:
                                yield {
                                    'type': pattern['name'],
                                    'severity': pattern['severity'],
                                    'file': filepath,
                                    'line': line_num,
                                    'match': self._redact(match.group()),
                                    'description': pattern.get('description', ''),
                                    'remediation': pattern.get('remediation', '')
                                }
                        except re.error:
                            # Skip invalid regex patterns
                            continue
        except Exception as e:
            yield {
                'type': 'scan_error',
                'severity': 'INFO',
                'file': filepath,
                'line': 0,
                'match': str(e),
                'description': 'Error scanning file',
                'remediation': 'Check file permissions and encoding'
            }

    def scan_directory(self, path: str) -> Generator[Dict, None, None]:
        """Recursively scan directory for secrets"""
        for filepath in self.file_handler.walk_directory(path):
            yield from self.scan_file(filepath)

    def _redact(self, secret: str, visible_chars: int = 4) -> str:
        """Redact secret, showing only first N chars"""
        if len(secret) <= visible_chars:
            return '*' * len(secret)
        return secret[:visible_chars] + '*' * (len(secret) - visible_chars)

    def scan(self, target: str) -> List[Dict]:
        """Main scan entry point"""
        findings = []

        if os.path.isfile(target):
            findings = list(self.scan_file(target))
        elif os.path.isdir(target):
            findings = list(self.scan_directory(target))
        else:
            raise ValueError(f"Target not found: {target}")

        return findings
