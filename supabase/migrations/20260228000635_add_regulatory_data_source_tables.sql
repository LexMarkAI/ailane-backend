-- Migration: 20260228000635_add_regulatory_data_source_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_regulatory_data_source_tables


CREATE TABLE hse_enforcement_notices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_identifier TEXT NOT NULL UNIQUE, notice_type TEXT NOT NULL, date_issued DATE NOT NULL,
  recipient_name TEXT, recipient_address TEXT, local_authority TEXT, region TEXT,
  sic_code TEXT, sector TEXT, legislation_breached TEXT, description TEXT,
  outcome TEXT, fine_amount NUMERIC,
  acei_category TEXT DEFAULT 'health_safety', acei_category_number INTEGER DEFAULT 10,
  source_url TEXT, content_hash TEXT, scraped_at TIMESTAMPTZ DEFAULT now(),
  metadata JSONB DEFAULT '{}'::jsonb, processing_status TEXT DEFAULT 'scraped'
);
CREATE INDEX idx_hse_date ON hse_enforcement_notices(date_issued);

CREATE TABLE ico_enforcement_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_identifier TEXT NOT NULL UNIQUE, action_type TEXT NOT NULL, date_issued DATE NOT NULL,
  organisation_name TEXT, sector TEXT, legislation TEXT, description TEXT,
  penalty_amount NUMERIC, data_subjects_affected INTEGER, employment_related BOOLEAN DEFAULT false,
  acei_category TEXT DEFAULT 'data_protection_privacy', acei_category_number INTEGER DEFAULT 11,
  source_url TEXT, content_hash TEXT, scraped_at TIMESTAMPTZ DEFAULT now(),
  metadata JSONB DEFAULT '{}'::jsonb, processing_status TEXT DEFAULT 'scraped'
);
CREATE INDEX idx_ico_date ON ico_enforcement_actions(date_issued);

CREATE TABLE ehrc_enforcement_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_identifier TEXT NOT NULL UNIQUE, action_type TEXT NOT NULL, date_issued DATE NOT NULL,
  organisation_name TEXT, sector TEXT, protected_characteristic TEXT, description TEXT, outcome TEXT,
  acei_category TEXT DEFAULT 'discrimination_harassment', acei_category_number INTEGER DEFAULT 2,
  source_url TEXT, content_hash TEXT, scraped_at TIMESTAMPTZ DEFAULT now(),
  metadata JSONB DEFAULT '{}'::jsonb, processing_status TEXT DEFAULT 'scraped'
);
CREATE INDEX idx_ehrc_date ON ehrc_enforcement_actions(date_issued);

CREATE TABLE legislative_changes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_identifier TEXT NOT NULL UNIQUE, title TEXT NOT NULL, legislation_type TEXT NOT NULL,
  year INTEGER, number INTEGER, date_enacted DATE, date_commenced DATE, date_published DATE,
  subject_tags TEXT[], employment_related BOOLEAN DEFAULT false,
  acei_categories TEXT[], sci_impact_level INTEGER CHECK (sci_impact_level BETWEEN 1 AND 5),
  description TEXT, status TEXT, amends TEXT[],
  source_url TEXT, content_hash TEXT, scraped_at TIMESTAMPTZ DEFAULT now(),
  metadata JSONB DEFAULT '{}'::jsonb, processing_status TEXT DEFAULT 'scraped'
);
CREATE INDEX idx_leg_date ON legislative_changes(date_enacted);
CREATE INDEX idx_leg_employment ON legislative_changes(employment_related);

CREATE TABLE hmcts_tribunal_statistics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_identifier TEXT NOT NULL UNIQUE,
  period_start DATE NOT NULL, period_end DATE NOT NULL, period_type TEXT NOT NULL,
  jurisdiction TEXT, acei_category TEXT,
  claims_received INTEGER, claims_disposed INTEGER,
  disposal_type TEXT, disposal_count INTEGER,
  median_weeks_to_hearing NUMERIC, successful_at_hearing_pct NUMERIC, median_award NUMERIC,
  source_url TEXT, scraped_at TIMESTAMPTZ DEFAULT now(), metadata JSONB DEFAULT '{}'::jsonb
);
CREATE INDEX idx_hmcts_period ON hmcts_tribunal_statistics(period_start, period_end);

CREATE VIEW enforcement_events_unified AS
SELECT id, 'hse' AS source, notice_type AS action_type, date_issued,
  recipient_name AS organisation, sector, fine_amount AS penalty_amount,
  acei_category, acei_category_number, source_url FROM hse_enforcement_notices
UNION ALL
SELECT id, 'ico' AS source, action_type, date_issued,
  organisation_name AS organisation, sector, penalty_amount,
  acei_category, acei_category_number, source_url FROM ico_enforcement_actions
UNION ALL
SELECT id, 'ehrc' AS source, action_type, date_issued,
  organisation_name AS organisation, sector, NULL AS penalty_amount,
  acei_category, acei_category_number, source_url FROM ehrc_enforcement_actions;

ALTER TABLE hse_enforcement_notices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read HSE" ON hse_enforcement_notices FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Scraper insert HSE" ON hse_enforcement_notices FOR INSERT TO anon WITH CHECK (true);
ALTER TABLE ico_enforcement_actions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read ICO" ON ico_enforcement_actions FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Scraper insert ICO" ON ico_enforcement_actions FOR INSERT TO anon WITH CHECK (true);
ALTER TABLE ehrc_enforcement_actions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read EHRC" ON ehrc_enforcement_actions FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Scraper insert EHRC" ON ehrc_enforcement_actions FOR INSERT TO anon WITH CHECK (true);
ALTER TABLE legislative_changes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read legislation" ON legislative_changes FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Scraper insert legislation" ON legislative_changes FOR INSERT TO anon WITH CHECK (true);
ALTER TABLE hmcts_tribunal_statistics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read HMCTS" ON hmcts_tribunal_statistics FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Scraper insert HMCTS" ON hmcts_tribunal_statistics FOR INSERT TO anon WITH CHECK (true);

INSERT INTO sources (id, name, base_url, jurisdiction, is_active) VALUES
  (gen_random_uuid(), 'HSE Enforcement Notices', 'https://resources.hse.gov.uk/notices/', 'UK', true),
  (gen_random_uuid(), 'ICO Enforcement Actions', 'https://ico.org.uk/action-weve-taken/enforcement/', 'UK', true),
  (gen_random_uuid(), 'EHRC Legal Action', 'https://www.equalityhumanrights.com/our-work/our-legal-action', 'UK', true),
  (gen_random_uuid(), 'HMCTS Tribunal Statistics', 'https://www.gov.uk/government/collections/tribunals-statistics', 'UK', true)
ON CONFLICT DO NOTHING;
