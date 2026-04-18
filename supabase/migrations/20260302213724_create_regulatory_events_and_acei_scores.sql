-- Migration: 20260302213724_create_regulatory_events_and_acei_scores
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_regulatory_events_and_acei_scores


-- ============================================================================
-- AILANE - Regulatory Events & ACEI Scores Tables
-- Constitutional Authority: ACEI Art. IV (EII), ACEI Art. V (SCI)
-- ============================================================================

-- Regulatory Events: stores enforcement actions and legislative changes
-- Fed by: enforcement_scraper.py (HSE/ICO/EHRC) and legislation_scraper.py
CREATE TABLE IF NOT EXISTS regulatory_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    source_identifier TEXT UNIQUE NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('enforcement', 'legislation', 'guidance', 'consultation')),
    title TEXT NOT NULL,
    description TEXT,
    source_url TEXT,
    jurisdiction TEXT DEFAULT 'UK',
    
    -- Enforcement-specific
    regulator TEXT,
    enforcement_type TEXT,
    eii_weight NUMERIC(4,2) DEFAULT 1.0,
    
    -- Legislation-specific
    legislation_type TEXT,
    significance_level INTEGER CHECK (significance_level BETWEEN 1 AND 5),
    
    -- ACEI linkage
    acei_category INTEGER CHECK (acei_category BETWEEN 1 AND 12),
    
    -- Metadata
    content_hash TEXT,
    event_date TEXT,
    scraped_at TIMESTAMPTZ DEFAULT NOW(),
    scraper_name TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for query performance
CREATE INDEX IF NOT EXISTS idx_reg_events_type ON regulatory_events(event_type);
CREATE INDEX IF NOT EXISTS idx_reg_events_category ON regulatory_events(acei_category);
CREATE INDEX IF NOT EXISTS idx_reg_events_jurisdiction ON regulatory_events(jurisdiction);
CREATE INDEX IF NOT EXISTS idx_reg_events_scraper ON regulatory_events(scraper_name);
CREATE INDEX IF NOT EXISTS idx_reg_events_date ON regulatory_events(event_date);

-- RLS policies for regulatory_events
ALTER TABLE regulatory_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY anon_read_regulatory_events ON regulatory_events
    FOR SELECT TO anon USING (true);

CREATE POLICY anon_insert_regulatory_events ON regulatory_events
    FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY service_all_regulatory_events ON regulatory_events
    FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ACEI Scores: historical score snapshots for trend analysis
CREATE TABLE IF NOT EXISTS acei_scores (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    domain_index NUMERIC(5,1) NOT NULL,
    category_scores JSONB NOT NULL DEFAULT '{}'::jsonb,
    computation_type TEXT DEFAULT 'weekly_recomputation',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_acei_scores_computed ON acei_scores(computed_at DESC);

-- RLS for acei_scores
ALTER TABLE acei_scores ENABLE ROW LEVEL SECURITY;

CREATE POLICY anon_read_acei_scores ON acei_scores
    FOR SELECT TO anon USING (true);

CREATE POLICY anon_insert_acei_scores ON acei_scores
    FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY service_all_acei_scores ON acei_scores
    FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- Alerts table (if not exists)
CREATE TABLE IF NOT EXISTS alerts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    alert_type TEXT NOT NULL,
    acei_category INTEGER,
    severity TEXT CHECK (severity IN ('info', 'low', 'medium', 'high', 'critical')),
    message TEXT,
    client_id UUID,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY anon_read_alerts ON alerts
    FOR SELECT TO anon USING (true);

CREATE POLICY anon_insert_alerts ON alerts
    FOR INSERT TO anon WITH CHECK (true);

