-- Seed data for Security Scanner Security Scanner
-- Sample patterns and test data

-- AWS patterns
INSERT INTO patterns (name, category, regex_pattern, severity_id, description) VALUES
(
    'aws_access_key_id',
    'aws',
    '(?:A3T[A-Z0-9]|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{16}',
    (SELECT id FROM severity_levels WHERE name = 'CRITICAL'),
    'AWS Access Key ID detected'
),
(
    'aws_secret_access_key',
    'aws',
    '(?i)aws_secret_access_key\s*[=:]\s*["'']?([A-Za-z0-9/+=]{40})["'']?',
    (SELECT id FROM severity_levels WHERE name = 'CRITICAL'),
    'AWS Secret Access Key detected'
)
ON CONFLICT (name) DO NOTHING;

-- Generic patterns
INSERT INTO patterns (name, category, regex_pattern, severity_id, description) VALUES
(
    'generic_api_key',
    'generic',
    '(?i)(api[_-]?key|apikey)\s*[=:]\s*["'']?([A-Za-z0-9_\-]{20,})["'']?',
    (SELECT id FROM severity_levels WHERE name = 'HIGH'),
    'Generic API key detected'
),
(
    'private_key',
    'generic',
    '-----BEGIN (?:RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----',
    (SELECT id FROM severity_levels WHERE name = 'CRITICAL'),
    'Private key detected'
),
(
    'github_token',
    'generic',
    'gh[pousr]_[A-Za-z0-9_]{36,}',
    (SELECT id FROM severity_levels WHERE name = 'CRITICAL'),
    'GitHub token detected'
)
ON CONFLICT (name) DO NOTHING;

-- Cloud patterns
INSERT INTO patterns (name, category, regex_pattern, severity_id, description) VALUES
(
    'gcp_api_key',
    'cloud',
    'AIza[0-9A-Za-z_-]{35}',
    (SELECT id FROM severity_levels WHERE name = 'CRITICAL'),
    'Google Cloud API key detected'
),
(
    'azure_connection_string',
    'cloud',
    '(?i)DefaultEndpointsProtocol=https?;.*AccountKey=[A-Za-z0-9+/=]{88}',
    (SELECT id FROM severity_levels WHERE name = 'CRITICAL'),
    'Azure storage connection string detected'
)
ON CONFLICT (name) DO NOTHING;

-- Sample scan data (for testing)
-- Uncomment for development/testing only
/*
INSERT INTO scans (scan_type, target, status, findings_count, created_by) VALUES
('secret', '/test/repo', 'completed', 5, 'test_user'),
('port', '192.168.1.1', 'completed', 3, 'test_user'),
('full', '/prod/app', 'running', 0, 'scanner_bot');

INSERT INTO findings (scan_id, severity_id, finding_type, title, description, location, line_number, remediation) VALUES
(
    1,
    (SELECT id FROM severity_levels WHERE name = 'CRITICAL'),
    'aws_access_key_id',
    'AWS Access Key Detected',
    'Hardcoded AWS access key found in configuration file',
    '/test/repo/config.py',
    42,
    'Rotate key immediately via IAM console'
);
*/
