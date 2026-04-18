-- Migration: 20260303002600_create_ceo_briefs_and_reports
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_ceo_briefs_and_reports


-- ============================================================================
-- AILANE CEO Daily Briefs, Reports & Document Archive
-- Constitutional Authority: AIC Governance (ACEI Art. X, RRI Art. X, CCI Art. X)
-- ============================================================================

-- Daily CEO Briefs
CREATE TABLE IF NOT EXISTS ceo_daily_briefs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Date
    brief_date DATE NOT NULL UNIQUE,
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Headline
    headline TEXT NOT NULL,                        -- e.g. "Strong infrastructure day"
    mood TEXT DEFAULT 'positive' CHECK (mood IN ('exceptional','positive','steady','challenging')),
    
    -- Progress Summary
    progress_summary TEXT NOT NULL,                -- What was accomplished today
    key_achievements JSONB DEFAULT '[]',           -- Array of achievement strings
    
    -- Platform Metrics Snapshot
    metrics_snapshot JSONB DEFAULT '{}',           -- {decisions, employers, legislation, enrichment_pct, di_score, ...}
    
    -- Pipeline Status
    pipeline_status JSONB DEFAULT '{}',            -- {companies_house_pct, deep_enrichment_pct, scrapers_active, ...}
    
    -- Tomorrow's Focus
    tomorrow_priorities JSONB DEFAULT '[]',        -- Array of priority items
    
    -- Week Ahead
    week_focus TEXT,                                -- What this week is about
    
    -- Company Milestones (running tracker)
    milestones_hit JSONB DEFAULT '[]',             -- Milestones achieved to date
    milestones_upcoming JSONB DEFAULT '[]',        -- Milestones coming up
    
    -- Valuation & Assets
    company_valuation JSONB DEFAULT '{}',          -- {estimated_value, basis, assets, ip, data_value}
    
    -- Financial
    financials JSONB DEFAULT '{}',                 -- {funding, burn_rate, runway, mrr, arr_target}
    
    -- Constitutional Compliance
    constitutional_status JSONB DEFAULT '{}',      -- {acei_compliant, rri_compliant, cci_compliant, amendments_pending}
    
    -- Notes
    ceo_notes TEXT,                                -- Manual notes added by Mark
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_briefs_date ON ceo_daily_briefs(brief_date DESC);

-- Auto-generated Reports
CREATE TABLE IF NOT EXISTS ceo_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    report_type TEXT NOT NULL CHECK (report_type IN (
        'daily_brief',
        'weekly_summary', 
        'monthly_review',
        'quarterly_board',
        'pipeline_status',
        'scraper_health',
        'enrichment_progress',
        'acei_movement',
        'client_intelligence',
        'valuation_update',
        'innovation_wales',
        'custom'
    )),
    
    title TEXT NOT NULL,
    period_start DATE,
    period_end DATE,
    
    -- Content
    content JSONB NOT NULL DEFAULT '{}',
    summary TEXT,
    
    -- Status
    status TEXT DEFAULT 'generated' CHECK (status IN ('generating','generated','reviewed','archived')),
    
    -- Metadata
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    tags TEXT[],
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reports_type ON ceo_reports(report_type);
CREATE INDEX IF NOT EXISTS idx_reports_date ON ceo_reports(generated_at DESC);

-- Company Documents Archive
CREATE TABLE IF NOT EXISTS company_documents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    category TEXT NOT NULL CHECK (category IN (
        'constitution',        -- ACEI, RRI, CCI founding docs
        'corporate',           -- Companies House filings, articles
        'financial',           -- Accounts, invoices, projections
        'legal',               -- Trademark, contracts, IP
        'funding',             -- Innovation Wales, investor materials
        'operations',          -- Feature matrix, architecture docs
        'reports',             -- Generated reports
        'correspondence'       -- Important external comms
    )),
    
    title TEXT NOT NULL,
    description TEXT,
    document_ref TEXT,                             -- e.g. "ACEI_v1.0", "UK00004347220"
    
    -- File reference (for future file storage integration)
    file_url TEXT,
    file_type TEXT,                                -- pdf, docx, xlsx
    file_size_bytes INTEGER,
    
    -- Metadata
    document_date DATE,
    expiry_date DATE,
    tags TEXT[],
    
    -- Status
    status TEXT DEFAULT 'active' CHECK (status IN ('active','superseded','expired','archived')),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_docs_category ON company_documents(category);
CREATE INDEX IF NOT EXISTS idx_docs_status ON company_documents(status);

-- RLS
ALTER TABLE ceo_daily_briefs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ceo_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY anon_read_briefs ON ceo_daily_briefs FOR SELECT TO anon USING (true);
CREATE POLICY anon_insert_briefs ON ceo_daily_briefs FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY anon_update_briefs ON ceo_daily_briefs FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY auth_all_briefs ON ceo_daily_briefs FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY anon_read_reports ON ceo_reports FOR SELECT TO anon USING (true);
CREATE POLICY anon_insert_reports ON ceo_reports FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY auth_all_reports ON ceo_reports FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY anon_read_docs ON company_documents FOR SELECT TO anon USING (true);
CREATE POLICY anon_insert_docs ON company_documents FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY anon_update_docs ON company_documents FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY auth_all_docs ON company_documents FOR ALL TO authenticated USING (true) WITH CHECK (true);

