-- Migration: 20260225145807_create_tribunal_decisions_table
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_tribunal_decisions_table


-- Table for raw scraped tribunal decisions from GOV.UK
CREATE TABLE IF NOT EXISTS tribunal_decisions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_identifier text UNIQUE NOT NULL,          -- GOV.UK decision URL or reference
    title text NOT NULL,
    decision_date date,
    jurisdiction text DEFAULT 'UK',
    tribunal_office text,                             -- e.g. London, Manchester, etc.
    
    -- ACEI v6.0 category classification (12 categories)
    acei_category text CHECK (acei_category IN (
        'unfair_dismissal',              -- Cat 1
        'discrimination_harassment',      -- Cat 2
        'wages_working_time',            -- Cat 3
        'whistleblowing',                -- Cat 4
        'employment_status',             -- Cat 5
        'redundancy_org_change',         -- Cat 6
        'parental_family_rights',        -- Cat 7
        'trade_union_collective',        -- Cat 8
        'breach_of_contract',            -- Cat 9
        'health_safety',                 -- Cat 10
        'data_protection_privacy',       -- Cat 11
        'business_transfers_insolvency', -- Cat 12
        'unclassified'
    )),
    acei_category_number integer CHECK (acei_category_number BETWEEN 1 AND 12),
    classification_confidence numeric CHECK (classification_confidence BETWEEN 0 AND 1),
    classification_keywords text[],
    
    -- Decision content
    summary text,
    outcome text,                                    -- e.g. 'claimant_won', 'respondent_won', 'settled', 'withdrawn'
    compensation_awarded numeric,
    
    -- Metadata
    scraped_at timestamptz DEFAULT now(),
    source_url text,
    content_hash text,                               -- For deduplication
    raw_html text,                                   -- Archive of raw page content
    metadata jsonb DEFAULT '{}'::jsonb,
    
    -- Processing status
    processing_status text DEFAULT 'raw' CHECK (processing_status IN ('raw', 'classified', 'verified', 'error')),
    error_details text
);

-- Indexes for common queries
CREATE INDEX idx_tribunal_decisions_category ON tribunal_decisions(acei_category);
CREATE INDEX idx_tribunal_decisions_date ON tribunal_decisions(decision_date);
CREATE INDEX idx_tribunal_decisions_scraped ON tribunal_decisions(scraped_at);
CREATE INDEX idx_tribunal_decisions_status ON tribunal_decisions(processing_status);
CREATE INDEX idx_tribunal_decisions_jurisdiction ON tribunal_decisions(jurisdiction, tribunal_office);

-- Scraper run log for audit trail
CREATE TABLE IF NOT EXISTS scraper_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    scraper_name text NOT NULL,
    started_at timestamptz DEFAULT now(),
    completed_at timestamptz,
    status text DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed', 'partial')),
    decisions_found integer DEFAULT 0,
    decisions_new integer DEFAULT 0,
    decisions_duplicate integer DEFAULT 0,
    decisions_errored integer DEFAULT 0,
    error_message text,
    metadata jsonb DEFAULT '{}'::jsonb
);

COMMENT ON TABLE tribunal_decisions IS 'Raw GOV.UK employment tribunal decisions - feeds ACEI v6.0 Event Volume Index (EVI)';
COMMENT ON TABLE scraper_runs IS 'Audit log for scraper execution - Article XI compliance';
