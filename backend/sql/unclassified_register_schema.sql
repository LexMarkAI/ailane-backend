-- =============================================================================
-- ACEI v6.0 - Unclassified Register Schema
-- Implements Article II requirement for 30-day review of unclassified events
-- =============================================================================

-- Drop existing table if re-running
DROP TABLE IF EXISTS unclassified_register CASCADE;

-- Create unclassified register table
CREATE TABLE unclassified_register (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_identifier TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    text_sample TEXT,
    url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    review_by_date TIMESTAMPTZ NOT NULL, -- 30 days from created_at
    reviewed_at TIMESTAMPTZ,
    reviewed_by TEXT,
    assigned_category TEXT,
    status TEXT CHECK (status IN ('pending_review', 'under_review', 'resolved', 'escalated')),
    resolution_notes TEXT,
    requires_taxonomy_amendment BOOLEAN DEFAULT FALSE,
    
    CONSTRAINT review_deadline CHECK (review_by_date = created_at + INTERVAL '30 days')
);

-- Create index for pending reviews
CREATE INDEX idx_unclassified_pending ON unclassified_register(status, review_by_date)
WHERE status IN ('pending_review', 'under_review');

-- Create index for overdue reviews
CREATE INDEX idx_unclassified_overdue ON unclassified_register(review_by_date)
WHERE status = 'pending_review' AND review_by_date < NOW();

-- =============================================================================
-- AUTOMATED ALERTS FOR OVERDUE REVIEWS
-- =============================================================================

-- Function to generate alerts for overdue unclassified items
CREATE OR REPLACE FUNCTION check_unclassified_deadlines()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO alerts (
        category,
        severity,
        message,
        metadata,
        created_at,
        acknowledged
    )
    SELECT
        'unclassified_register_overdue' as category,
        'high' as severity,
        'Unclassified Register: ' || COUNT(*) || ' items past 30-day review deadline' as message,
        jsonb_build_object(
            'overdue_count', COUNT(*),
            'oldest_item', MIN(created_at),
            'review_required', true
        ) as metadata,
        NOW() as created_at,
        false as acknowledged
    FROM unclassified_register
    WHERE status = 'pending_review' 
    AND review_by_date < NOW()
    HAVING COUNT(*) > 0;
END;
$$;

-- =============================================================================
-- HELPER VIEWS
-- =============================================================================

-- View: Pending reviews (within deadline)
CREATE OR REPLACE VIEW v_unclassified_pending AS
SELECT 
    id,
    source_identifier,
    title,
    created_at,
    review_by_date,
    (review_by_date - NOW()) as time_remaining,
    EXTRACT(DAY FROM (review_by_date - NOW())) as days_remaining
FROM unclassified_register
WHERE status = 'pending_review'
AND review_by_date >= NOW()
ORDER BY review_by_date ASC;

-- View: Overdue reviews (past deadline)
CREATE OR REPLACE VIEW v_unclassified_overdue AS
SELECT 
    id,
    source_identifier,
    title,
    created_at,
    review_by_date,
    (NOW() - review_by_date) as time_overdue,
    EXTRACT(DAY FROM (NOW() - review_by_date)) as days_overdue
FROM unclassified_register
WHERE status = 'pending_review'
AND review_by_date < NOW()
ORDER BY review_by_date ASC;

-- View: Statistics dashboard
CREATE OR REPLACE VIEW v_unclassified_stats AS
SELECT
    COUNT(*) FILTER (WHERE status = 'pending_review') as pending_count,
    COUNT(*) FILTER (WHERE status = 'pending_review' AND review_by_date < NOW()) as overdue_count,
    COUNT(*) FILTER (WHERE status = 'resolved') as resolved_count,
    COUNT(*) FILTER (WHERE requires_taxonomy_amendment = true) as taxonomy_amendments_needed,
    AVG(EXTRACT(DAY FROM (reviewed_at - created_at))) FILTER (WHERE reviewed_at IS NOT NULL) as avg_review_days,
    MIN(review_by_date) FILTER (WHERE status = 'pending_review') as next_deadline
FROM unclassified_register;

-- =============================================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- Enable RLS
ALTER TABLE unclassified_register ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read all
CREATE POLICY "Allow authenticated read access"
ON unclassified_register
FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow service role to insert
CREATE POLICY "Allow service role to insert"
ON unclassified_register
FOR INSERT
TO service_role
WITH CHECK (true);

-- Policy: Allow authenticated users to update
CREATE POLICY "Allow authenticated update"
ON unclassified_register
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- =============================================================================
-- SAMPLE DATA (FOR TESTING)
-- =============================================================================

-- Insert sample unclassified item
INSERT INTO unclassified_register (
    source_identifier,
    title,
    text_sample,
    url,
    review_by_date,
    status
) VALUES (
    'ET-2026-TEST-001',
    'Sample unclassified tribunal decision',
    'This decision contains unusual legal terminology that did not match any category keywords...',
    'https://www.gov.uk/employment-tribunal-decisions/ET-2026-TEST-001',
    NOW() + INTERVAL '30 days',
    'pending_review'
);

-- =============================================================================
-- MAINTENANCE QUERIES
-- =============================================================================

-- Query: Show all pending reviews ordered by deadline
SELECT * FROM v_unclassified_pending;

-- Query: Show overdue reviews
SELECT * FROM v_unclassified_overdue;

-- Query: Show statistics
SELECT * FROM v_unclassified_stats;

-- Query: Mark item as resolved with assigned category
UPDATE unclassified_register
SET 
    status = 'resolved',
    reviewed_at = NOW(),
    reviewed_by = 'governance_team',
    assigned_category = 'whistleblowing_protected_disclosure',
    resolution_notes = 'Manually classified based on substantive legal test'
WHERE source_identifier = 'ET-2026-TEST-001';

-- Query: Flag item as requiring taxonomy amendment
UPDATE unclassified_register
SET 
    status = 'escalated',
    requires_taxonomy_amendment = true,
    resolution_notes = 'Novel legal area - may require new category in v7.0'
WHERE id = 'some-uuid-here';

COMMENT ON TABLE unclassified_register IS 'Article II requirement: Events not immediately classifiable shall be logged and reviewed within 30 days. No permanent Miscellaneous category permitted.';
