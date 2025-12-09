"""Generic secret patterns"""

GENERIC_PATTERNS = [
    {
        'name': 'generic_api_key',
        'regex': r'(?i)(api[_-]?key|apikey)\s*[=:]\s*["\']?([A-Za-z0-9_\-]{20,})["\']?',
        'severity': 'HIGH',
        'description': 'Generic API key detected',
        'remediation': 'Move to environment variables or secrets manager'
    },
    {
        'name': 'generic_secret',
        'regex': r'(?i)(secret|password|passwd|pwd)\s*[=:]\s*["\']?([^\s"\']{8,})["\']?',
        'severity': 'HIGH',
        'description': 'Hardcoded secret or password detected',
        'remediation': 'Use environment variables or secrets manager'
    },
    {
        'name': 'private_key',
        'regex': r'-----BEGIN (?:RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----',
        'severity': 'CRITICAL',
        'description': 'Private key detected',
        'remediation': 'Remove from repository, regenerate key pair'
    },
    {
        'name': 'jwt_token',
        'regex': r'eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*',
        'severity': 'MEDIUM',
        'description': 'JWT token detected',
        'remediation': 'Tokens should not be hardcoded, use runtime generation'
    },
    {
        'name': 'github_token',
        'regex': r'gh[pousr]_[A-Za-z0-9_]{36,}',
        'severity': 'CRITICAL',
        'description': 'GitHub token detected',
        'remediation': 'Revoke token immediately and rotate'
    },
    {
        'name': 'slack_token',
        'regex': r'xox[baprs]-[0-9]{10,13}-[0-9]{10,13}-[A-Za-z0-9]{24,}',
        'severity': 'HIGH',
        'description': 'Slack token detected',
        'remediation': 'Revoke token and use environment variables'
    }
]
