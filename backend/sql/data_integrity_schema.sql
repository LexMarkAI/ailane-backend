-- =============================================================================
-- ACEI v6.0 - Data Integrity & Audit Layer Schema
-- Phase 1, Week 1, Priority 1C
-- =============================================================================

-- =============================================================================
-- AUDIT LOG (Immutable)
-- =============================================================================

CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL CHECK (event_type IN (
        'insert', 'update', 'delete', 'scrape', 'categorization',
        'mitigation_upload', 'alert_generated', 'manual_review'
    )),
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changes JSONB NOT NULL,
    reason TEXT NOT NULL,
    ip_address INET,
    
    -- Immutability: No updates or deletes allowed after insert
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Indexes for performance
CREATE INDEX idx_audit_log_table_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_timestamp ON audit_log(timestamp DESC);
CREATE INDEX idx_audit_log_event_type ON audit_log(event_type);
CREATE INDEX idx_audit_log_user ON audit_log(user_id);

-- Prevent updates and deletes (immutability)
CREATE OR REPLACE FUNCTION prevent_audit_log_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit log is immutable - modifications not allowed';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_log_immutable_update
    BEFORE UPDATE ON audit_log
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_log_modification();

CREATE TRIGGER audit_log_immutable_delete
    BEFORE DELETE ON audit_log
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_log_modification();

-- =============================================================================
-- DECISION VERSIONS (Complete history)
-- =============================================================================

CREATE TABLE IF NOT EXISTS decision_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_identifier TEXT NOT NULL,
    version INT NOT NULL CHECK (version > 0),
    content_hash TEXT NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by TEXT NOT NULL,
    change_reason TEXT NOT NULL,
    previous_version_id UUID REFERENCES decision_versions(id),
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    UNIQUE(source_identifier, version)
);

-- Indexes
CREATE INDEX idx_decision_versions_identifier ON decision_versions(source_identifier);
CREATE INDEX idx_decision_versions_hash ON decision_versions(content_hash);
CREATE INDEX idx_decision_versions_changed ON decision_versions(changed_at DESC);

-- =============================================================================
-- DATA QUALITY ISSUES LOG
-- =============================================================================

CREATE TABLE IF NOT EXISTS data_quality_issues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    record_id TEXT NOT NULL,
    table_name TEXT NOT NULL DEFAULT 'regulatory_updates',
    field_name TEXT NOT NULL,
    issue_type TEXT NOT NULL CHECK (issue_type IN (
        'missing', 'invalid', 'malformed', 'suspicious', 'duplicate'
    )),
    severity TEXT NOT NULL CHECK (severity IN (
        'critical', 'warning', 'info'
    )),
    description TEXT NOT NULL,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by TEXT,
    resolution_notes TEXT,
    
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'ignored'))
);

-- Indexes
CREATE INDEX idx_dq_issues_record ON data_quality_issues(record_id);
CREATE INDEX idx_dq_issues_status ON data_quality_issues(status) WHERE status = 'open';
CREATE INDEX idx_dq_issues_severity ON data_quality_issues(severity) WHERE severity = 'critical';
CREATE INDEX idx_dq_issues_detected ON data_quality_issues(detected_at DESC);

-- =============================================================================
-- HELPER VIEWS
-- =============================================================================

-- View: Recent audit events (last 24 hours)
CREATE OR REPLACE VIEW v_recent_audit_events AS
SELECT 
    id,
    event_type,
    table_name,
    record_id,
    user_id,
    timestamp,
    reason,
    (timestamp AT TIME ZONE 'UTC') as utc_timestamp
FROM audit_log
WHERE timestamp >= NOW() - INTERVAL '24 hours'
ORDER BY timestamp DESC;

-- View: Decision version history
CREATE OR REPLACE VIEW v_decision_version_history AS
SELECT 
    dv.source_identifier,
    dv.version,
    dv.changed_at,
    dv.changed_by,
    dv.change_reason,
    dv.content_hash,
    LAG(dv.content_hash) OVER (
        PARTITION BY dv.source_identifier 
        ORDER BY dv.version
    ) as previous_hash,
    CASE 
        WHEN LAG(dv.content_hash) OVER (
            PARTITION BY dv.source_identifier 
            ORDER BY dv.version
        ) IS NULL THEN 'initial'
        ELSE 'update'
    END as change_type
FROM decision_versions dv
ORDER BY dv.source_identifier, dv.version;

-- View: Open data quality issues summary
CREATE OR REPLACE VIEW v_open_quality_issues AS
SELECT 
    severity,
    issue_type,
    COUNT(*) as count,
    MIN(detected_at) as oldest_issue,
    MAX(detected_at) as newest_issue
FROM data_quality_issues
WHERE status = 'open'
GROUP BY severity, issue_type
ORDER BY 
    CASE severity 
        WHEN 'critical' THEN 1
        WHEN 'warning' THEN 2
        WHEN 'info' THEN 3
    END,
    count DESC;

-- View: Audit trail for specific record
CREATE OR REPLACE FUNCTION get_audit_trail(
    p_table_name TEXT,
    p_record_id TEXT
)
RETURNS TABLE (
    event_type TEXT,
    user_id TEXT,
    timestamp TIMESTAMPTZ,
    changes JSONB,
    reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.event_type,
        a.user_id,
        a.timestamp,
        a.changes,
        a.reason
    FROM audit_log a
    WHERE a.table_name = p_table_name
    AND a.record_id = p_record_id
    ORDER BY a.timestamp ASC;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE decision_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_quality_issues ENABLE ROW LEVEL SECURITY;

-- Audit log: Read-only for authenticated, write for service role
CREATE POLICY "Allow authenticated read audit log"
ON audit_log FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow service role to insert audit log"
ON audit_log FOR INSERT
TO service_role
WITH CHECK (true);

-- Decision versions: Similar policies
CREATE POLICY "Allow authenticated read versions"
ON decision_versions FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow service role to insert versions"
ON decision_versions FOR INSERT
TO service_role
WITH CHECK (true);

-- Data quality issues: Full access for authenticated
CREATE POLICY "Allow authenticated full access to quality issues"
ON data_quality_issues FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Function: Log audit event (convenience wrapper)
CREATE OR REPLACE FUNCTION log_audit_event(
    p_event_type TEXT,
    p_table_name TEXT,
    p_record_id TEXT,
    p_user_id TEXT,
    p_changes JSONB,
    p_reason TEXT,
    p_ip_address INET DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_audit_id UUID;
BEGIN
    INSERT INTO audit_log (
        event_type,
        table_name,
        record_id,
        user_id,
        changes,
        reason,
        ip_address
    ) VALUES (
        p_event_type,
        p_table_name,
        p_record_id,
        p_user_id,
        p_changes,
        p_reason,
        p_ip_address
    )
    RETURNING id INTO v_audit_id;
    
    RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Create version record (convenience wrapper)
CREATE OR REPLACE FUNCTION create_version_record(
    p_source_identifier TEXT,
    p_version INT,
    p_content_hash TEXT,
    p_changed_by TEXT,
    p_change_reason TEXT,
    p_previous_version_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_version_id UUID;
BEGIN
    INSERT INTO decision_versions (
        source_identifier,
        version,
        content_hash,
        changed_by,
        change_reason,
        previous_version_id
    ) VALUES (
        p_source_identifier,
        p_version,
        p_content_hash,
        p_changed_by,
        p_change_reason,
        p_previous_version_id
    )
    RETURNING id INTO v_version_id;
    
    RETURN v_version_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- SAMPLE QUERIES
-- =============================================================================

-- Get audit trail for a decision
-- SELECT * FROM get_audit_trail('regulatory_updates', 'ET-2026-001234');

-- Get version history for a decision
-- SELECT * FROM v_decision_version_history WHERE source_identifier = 'ET-2026-001234';

-- Get open quality issues summary
-- SELECT * FROM v_open_quality_issues;

-- Get recent audit events
-- SELECT * FROM v_recent_audit_events LIMIT 50;

-- Log a sample audit event
-- SELECT log_audit_event(
--     'scrape',
--     'regulatory_updates',
--     'ET-2026-001234',
--     'scraper',
--     '{"action": "new_scrape", "source": "GOV.UK"}'::jsonb,
--     'Automated scrape from GOV.UK'
-- );

COMMENT ON TABLE audit_log IS 'Immutable audit log per Article XI - all data modifications tracked';
COMMENT ON TABLE decision_versions IS 'Complete version history for all tribunal decisions';
COMMENT ON TABLE data_quality_issues IS 'Data quality check failures requiring review';
