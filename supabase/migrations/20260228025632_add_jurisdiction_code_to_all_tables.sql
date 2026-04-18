-- Migration: 20260228025632_add_jurisdiction_code_to_all_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_jurisdiction_code_to_all_tables


-- ═══════════════════════════════════════════════════════════════
-- LAYER 3: ADD jurisdiction_code TO ALL DATA & SCORING TABLES
-- All existing data defaults to 'GB' — zero disruption
-- ═══════════════════════════════════════════════════════════════

-- Scoring tables
ALTER TABLE acei_domain_scores ADD COLUMN IF NOT EXISTS jurisdiction_code VARCHAR(10) NOT NULL DEFAULT 'GB' REFERENCES jurisdictions(code);
ALTER TABLE acei_category_scores ADD COLUMN IF NOT EXISTS jurisdiction_code VARCHAR(10) NOT NULL DEFAULT 'GB' REFERENCES jurisdictions(code);

-- Data collection tables
ALTER TABLE tribunal_decisions ADD COLUMN IF NOT EXISTS jurisdiction_code VARCHAR(10) NOT NULL DEFAULT 'GB' REFERENCES jurisdictions(code);
ALTER TABLE legislative_changes ADD COLUMN IF NOT EXISTS jurisdiction_code VARCHAR(10) NOT NULL DEFAULT 'GB' REFERENCES jurisdictions(code);
ALTER TABLE hse_enforcement_notices ADD COLUMN IF NOT EXISTS jurisdiction_code VARCHAR(10) NOT NULL DEFAULT 'GB' REFERENCES jurisdictions(code);
ALTER TABLE ico_enforcement_actions ADD COLUMN IF NOT EXISTS jurisdiction_code VARCHAR(10) NOT NULL DEFAULT 'GB' REFERENCES jurisdictions(code);
ALTER TABLE ehrc_enforcement_actions ADD COLUMN IF NOT EXISTS jurisdiction_code VARCHAR(10) NOT NULL DEFAULT 'GB' REFERENCES jurisdictions(code);
ALTER TABLE hmcts_tribunal_statistics ADD COLUMN IF NOT EXISTS jurisdiction_code VARCHAR(10) NOT NULL DEFAULT 'GB' REFERENCES jurisdictions(code);
ALTER TABLE scraper_runs ADD COLUMN IF NOT EXISTS jurisdiction_code VARCHAR(10) NOT NULL DEFAULT 'GB' REFERENCES jurisdictions(code);

-- Organisation tables
ALTER TABLE organisations ADD COLUMN IF NOT EXISTS primary_jurisdiction_code VARCHAR(10) DEFAULT 'GB' REFERENCES jurisdictions(code);
ALTER TABLE early_access_signups ADD COLUMN IF NOT EXISTS jurisdiction_code VARCHAR(10) DEFAULT NULL;

-- Multi-jurisdiction org mapping (ACEI Art VIII §8.2.1)
CREATE TABLE IF NOT EXISTS org_jurisdictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organisations(id),
  jurisdiction_code VARCHAR(10) NOT NULL REFERENCES jurisdictions(code),
  workforce_weight NUMERIC(5,4) NOT NULL DEFAULT 1.0000,
  headcount INTEGER,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, jurisdiction_code)
);

ALTER TABLE org_jurisdictions ENABLE ROW LEVEL SECURITY;

-- Performance indices
CREATE INDEX IF NOT EXISTS idx_acei_domain_jur_week ON acei_domain_scores(jurisdiction_code, week_start_date DESC);
CREATE INDEX IF NOT EXISTS idx_acei_cat_jur_week ON acei_category_scores(jurisdiction_code, week_start_date DESC);
CREATE INDEX IF NOT EXISTS idx_tribunal_jur_date ON tribunal_decisions(jurisdiction_code, decision_date DESC);
CREATE INDEX IF NOT EXISTS idx_legislative_jur_date ON legislative_changes(jurisdiction_code, date_enacted DESC);
CREATE INDEX IF NOT EXISTS idx_scraper_runs_jur ON scraper_runs(jurisdiction_code);

