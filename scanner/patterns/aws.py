"""AWS credential patterns"""

AWS_PATTERNS = [
    {
        'name': 'aws_access_key_id',
        'regex': r'(?:A3T[A-Z0-9]|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{16}',
        'severity': 'CRITICAL',
        'description': 'AWS Access Key ID detected',
        'remediation': 'Rotate key immediately via IAM console, revoke compromised key'
    },
    {
        'name': 'aws_secret_access_key',
        'regex': r'(?i)aws_secret_access_key\s*[=:]\s*["\']?([A-Za-z0-9/+=]{40})["\']?',
        'severity': 'CRITICAL',
        'description': 'AWS Secret Access Key detected',
        'remediation': 'Rotate credentials immediately, use IAM roles or AWS Secrets Manager'
    },
    {
        'name': 'aws_session_token',
        'regex': r'(?i)aws_session_token\s*[=:]\s*["\']?([A-Za-z0-9/+=]{100,})["\']?',
        'severity': 'HIGH',
        'description': 'AWS Session Token detected',
        'remediation': 'Session tokens are temporary but should not be committed'
    },
    {
        'name': 'aws_account_id',
        'regex': r'(?i)aws_account[_-]?id\s*[=:]\s*["\']?(\d{12})["\']?',
        'severity': 'MEDIUM',
        'description': 'AWS Account ID detected',
        'remediation': 'Account IDs are not highly sensitive but should be in config'
    }
]
