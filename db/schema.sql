-- freesscan Database Schema
-- PostgreSQL 15+

-- Severity levels
CREATE TABLE IF NOT EXISTS severity_levels (
    id SERIAL PRIMARY KEY,
    name VARCHAR(20) NOT NULL UNIQUE,
    weight INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert severity levels
INSERT INTO severity_levels (name, weight) VALUES
    ('CRITICAL', 100),
    ('HIGH', 75),
    ('MEDIUM', 50),
    ('LOW', 25),
    ('INFO', 10)
ON CONFLICT (name) DO NOTHING;

-- Scan runs
CREATE TABLE IF NOT EXISTS scans (
    id SERIAL PRIMARY KEY,
    scan_type VARCHAR(50) NOT NULL,        -- 'secret' | 'port' | 'full'
    target VARCHAR(500) NOT NULL,          -- repo path or IP/hostname
    status VARCHAR(20) DEFAULT 'running',  -- 'running' | 'completed' | 'failed'
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    findings_count INTEGER DEFAULT 0,
    metadata JSONB,
    created_by VARCHAR(100),
    CONSTRAINT valid_scan_type CHECK (scan_type IN ('secret', 'port', 'full')),
    CONSTRAINT valid_status CHECK (status IN ('running', 'completed', 'failed'))
);

-- Findings
CREATE TABLE IF NOT EXISTS findings (
    id SERIAL PRIMARY KEY,
    scan_id INTEGER REFERENCES scans(id) ON DELETE CASCADE,
    severity_id INTEGER REFERENCES severity_levels(id),
    finding_type VARCHAR(100) NOT NULL,    -- 'aws_access_key' | 'open_port' | etc.
    title VARCHAR(255) NOT NULL,
    description TEXT,
    location VARCHAR(500),                 -- file path or IP:port
    line_number INTEGER,
    matched_content TEXT,                  -- redacted secret or service banner
    remediation TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    is_false_positive BOOLEAN DEFAULT FALSE,
    reviewed_at TIMESTAMP,
    reviewed_by VARCHAR(100),
    notes TEXT
);

-- Pattern definitions (for custom patterns)
CREATE TABLE IF NOT EXISTS patterns (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL,         -- 'aws' | 'generic' | 'cloud'
    regex_pattern TEXT NOT NULL,
    severity_id INTEGER REFERENCES severity_levels(id),
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Scan history for tracking changes
CREATE TABLE IF NOT EXISTS scan_history (
    id SERIAL PRIMARY KEY,
    scan_id INTEGER REFERENCES scans(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,       -- 'started' | 'completed' | 'failed'
    event_data JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_findings_scan_id ON findings(scan_id);
CREATE INDEX IF NOT EXISTS idx_findings_severity ON findings(severity_id);
CREATE INDEX IF NOT EXISTS idx_findings_type ON findings(finding_type);
CREATE INDEX IF NOT EXISTS idx_findings_false_positive ON findings(is_false_positive);
CREATE INDEX IF NOT EXISTS idx_scans_status ON scans(status);
CREATE INDEX IF NOT EXISTS idx_scans_target ON scans(target);
CREATE INDEX IF NOT EXISTS idx_scans_created ON scans(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_patterns_active ON patterns(is_active) WHERE is_active = TRUE;

-- Views for common queries
CREATE OR REPLACE VIEW v_scan_summary AS
SELECT
    s.id,
    s.scan_type,
    s.target,
    s.status,
    s.started_at,
    s.completed_at,
    s.findings_count,
    COUNT(DISTINCT f.id) FILTER (WHERE sl.name = 'CRITICAL') as critical_count,
    COUNT(DISTINCT f.id) FILTER (WHERE sl.name = 'HIGH') as high_count,
    COUNT(DISTINCT f.id) FILTER (WHERE sl.name = 'MEDIUM') as medium_count,
    COUNT(DISTINCT f.id) FILTER (WHERE sl.name = 'LOW') as low_count,
    COUNT(DISTINCT f.id) FILTER (WHERE f.is_false_positive = FALSE) as real_findings_count
FROM scans s
LEFT JOIN findings f ON s.id = f.scan_id
LEFT JOIN severity_levels sl ON f.severity_id = sl.id
GROUP BY s.id;

-- Function to update scan statistics
CREATE OR REPLACE FUNCTION update_scan_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE scans
    SET findings_count = (
        SELECT COUNT(*) FROM findings WHERE scan_id = NEW.scan_id
    )
    WHERE id = NEW.scan_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update scan statistics
DROP TRIGGER IF EXISTS trg_update_scan_stats ON findings;
CREATE TRIGGER trg_update_scan_stats
    AFTER INSERT OR UPDATE OR DELETE ON findings
    FOR EACH ROW
    EXECUTE FUNCTION update_scan_stats();

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO scanner;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO scanner;
