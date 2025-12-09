"""Cloud provider credential patterns"""

CLOUD_PATTERNS = [
    {
        'name': 'gcp_api_key',
        'regex': r'AIza[0-9A-Za-z_-]{35}',
        'severity': 'CRITICAL',
        'description': 'Google Cloud API key detected',
        'remediation': 'Rotate key immediately via GCP console'
    },
    {
        'name': 'gcp_service_account',
        'regex': r'"type":\s*"service_account"',
        'severity': 'CRITICAL',
        'description': 'GCP service account JSON detected',
        'remediation': 'Remove service account file, use workload identity'
    },
    {
        'name': 'azure_connection_string',
        'regex': r'(?i)DefaultEndpointsProtocol=https?;.*AccountKey=[A-Za-z0-9+/=]{88}',
        'severity': 'CRITICAL',
        'description': 'Azure storage connection string detected',
        'remediation': 'Rotate storage key and use managed identities'
    },
    {
        'name': 'azure_client_secret',
        'regex': r'(?i)client[_-]?secret\s*[=:]\s*["\']?([A-Za-z0-9~._-]{34,})["\']?',
        'severity': 'HIGH',
        'description': 'Azure client secret detected',
        'remediation': 'Rotate secret via Azure AD app registration'
    },
    {
        'name': 'heroku_api_key',
        'regex': r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
        'severity': 'HIGH',
        'description': 'Heroku API key detected',
        'remediation': 'Regenerate API key from Heroku account settings'
    }
]
