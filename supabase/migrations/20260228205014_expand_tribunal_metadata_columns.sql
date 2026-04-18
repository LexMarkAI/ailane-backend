-- Migration: 20260228205014_expand_tribunal_metadata_columns
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: expand_tribunal_metadata_columns


-- ═══════════════════════════════════════════════════════════
-- EXPANDED TRIBUNAL METADATA SCHEMA
-- Constitutional Authority: ACEI Art II, CCI Art III/V
-- Purpose: Deep metadata extraction for multi-index scoring
-- ═══════════════════════════════════════════════════════════

-- Layer 1: Extractable from existing title/raw_html data
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS respondent_name TEXT;
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS claimant_name TEXT;
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS case_number TEXT;
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS decision_types TEXT[];
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS respondent_status TEXT DEFAULT 'active';
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS is_multi_respondent BOOLEAN DEFAULT false;
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS document_count SMALLINT DEFAULT 1;

-- Layer 2: From GOV.UK page metadata (enrichment scrape)
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS jurisdiction_codes TEXT[];
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS acei_categories_all TEXT[];
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS country_region TEXT;
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS published_date DATE;
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS pdf_urls TEXT[];

-- Indexes for the critical query patterns
CREATE INDEX IF NOT EXISTS idx_td_respondent ON tribunal_decisions (respondent_name);
CREATE INDEX IF NOT EXISTS idx_td_decision_types ON tribunal_decisions USING GIN (decision_types);
CREATE INDEX IF NOT EXISTS idx_td_jurisdiction_codes ON tribunal_decisions USING GIN (jurisdiction_codes);
CREATE INDEX IF NOT EXISTS idx_td_categories_all ON tribunal_decisions USING GIN (acei_categories_all);
CREATE INDEX IF NOT EXISTS idx_td_country_region ON tribunal_decisions (country_region);
CREATE INDEX IF NOT EXISTS idx_td_respondent_status ON tribunal_decisions (respondent_status);
CREATE INDEX IF NOT EXISTS idx_td_processing_status ON tribunal_decisions (processing_status);

-- Composite index for CCI: respondent + category + date
CREATE INDEX IF NOT EXISTS idx_td_respondent_category_date 
  ON tribunal_decisions (respondent_name, acei_category, decision_date);

-- Comment the new columns
COMMENT ON COLUMN tribunal_decisions.respondent_name IS 'Employer/organisation name extracted from title. Critical for CCI per-employer scoring.';
COMMENT ON COLUMN tribunal_decisions.claimant_name IS 'Individual claimant name extracted from title.';
COMMENT ON COLUMN tribunal_decisions.decision_types IS 'Array of decision document types: Judgment, Strike Out, Withdrawal, Rule 21, Remedy, Costs, etc.';
COMMENT ON COLUMN tribunal_decisions.respondent_status IS 'Insolvency status: active, in_administration, in_liquidation, in_receivership, dissolved.';
COMMENT ON COLUMN tribunal_decisions.jurisdiction_codes IS 'All GOV.UK jurisdiction codes as array (e.g. Disability Discrimination, Unfair Dismissal).';
COMMENT ON COLUMN tribunal_decisions.acei_categories_all IS 'All mapped ACEI categories. Primary in acei_category; full composition here.';
COMMENT ON COLUMN tribunal_decisions.country_region IS 'England and Wales or Scotland.';
COMMENT ON COLUMN tribunal_decisions.pdf_urls IS 'URLs to judgment PDF documents on assets.publishing.service.gov.uk.';

