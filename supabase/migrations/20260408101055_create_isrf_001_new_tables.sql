-- Migration: 20260408101055_create_isrf_001_new_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_isrf_001_new_tables


-- AILANE-SPEC-ISRF-001 v1.0 — New Intelligence Tables
-- AMD-038 | Ratified 8 April 2026
-- Note: ico_enforcement_actions and ehrc_enforcement_actions already exist with prior schema

-- 1. NCSC Alerts
CREATE TABLE ncsc_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_date DATE NOT NULL,
  title TEXT NOT NULL,
  summary TEXT,
  source_url TEXT NOT NULL UNIQUE,
  alert_type TEXT NOT NULL CHECK (alert_type IN ('alert', 'advisory', 'guidance', 'blog', 'news', 'malware_report')),
  severity TEXT,
  targeted_domains TEXT[],
  targeted_systems TEXT[],
  mitre_attack_ids TEXT[],
  acei_categories INTEGER[],
  employer_relevance_summary TEXT,
  source_feed TEXT NOT NULL CHECK (source_feed IN ('ncsc-alerts-advisories', 'ncsc-news')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_ncsc_alerts_date ON ncsc_alerts (alert_date DESC);
CREATE INDEX idx_ncsc_alerts_type ON ncsc_alerts (alert_type);

-- 2. HMRC NMW Naming Rounds
CREATE TABLE hmrc_nmw_naming (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  naming_round_date DATE NOT NULL,
  employer_name TEXT NOT NULL,
  employer_ch_number TEXT,
  total_underpayment NUMERIC,
  workers_affected INTEGER,
  breach_type TEXT,
  source_url TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (naming_round_date, employer_name)
);
CREATE INDEX idx_hmrc_nmw_date ON hmrc_nmw_naming (naming_round_date DESC);

-- 3. International Cyber Alerts
CREATE TABLE intl_cyber_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_org TEXT NOT NULL,
  alert_date DATE NOT NULL,
  title TEXT NOT NULL,
  summary TEXT,
  source_url TEXT NOT NULL UNIQUE,
  severity TEXT,
  acei_categories INTEGER[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_intl_cyber_date ON intl_cyber_alerts (alert_date DESC);

-- 4. GOV.UK Policy Papers
CREATE TABLE govuk_policy_papers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  published_date DATE NOT NULL,
  title TEXT NOT NULL,
  document_type TEXT NOT NULL CHECK (document_type IN ('consultation', 'policy_paper', 'impact_assessment', 'guidance', 'research', 'statistics')),
  topic_tags TEXT[],
  status TEXT,
  closing_date DATE,
  source_url TEXT NOT NULL UNIQUE,
  acei_categories INTEGER[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_govuk_papers_date ON govuk_policy_papers (published_date DESC);

-- 5. MI5 Threat Levels
CREATE TABLE mi5_threat_levels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  effective_date DATE NOT NULL,
  threat_level TEXT NOT NULL CHECK (threat_level IN ('low', 'moderate', 'substantial', 'severe', 'critical')),
  previous_level TEXT,
  change_summary TEXT,
  source_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_mi5_threat_date ON mi5_threat_levels (effective_date DESC);

-- 6. NPSA Protective Security Guidance
CREATE TABLE npsa_guidance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  published_date DATE NOT NULL,
  title TEXT NOT NULL,
  guidance_type TEXT NOT NULL CHECK (guidance_type IN ('insider_risk', 'personnel_security', 'physical_security', 'ncst', 'trusted_research', 'general')),
  summary TEXT,
  source_url TEXT NOT NULL UNIQUE,
  acei_categories INTEGER[] NOT NULL DEFAULT ARRAY[10],
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_npsa_guidance_date ON npsa_guidance (published_date DESC);

-- 7. NCA Fraud Alerts
CREATE TABLE nca_fraud_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_date DATE NOT NULL,
  title TEXT NOT NULL,
  fraud_type TEXT NOT NULL CHECK (fraud_type IN ('invoice', 'bec', 'cyber', 'crypto', 'impersonation', 'mandate', 'other')),
  sector_tags TEXT[],
  summary TEXT,
  source_url TEXT NOT NULL UNIQUE,
  acei_categories INTEGER[] NOT NULL DEFAULT ARRAY[9, 11],
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_nca_fraud_date ON nca_fraud_alerts (alert_date DESC);

-- 8. Report Fraud UK
CREATE TABLE report_fraud_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  published_date DATE NOT NULL,
  title TEXT NOT NULL,
  fraud_category TEXT,
  summary TEXT,
  source_url TEXT NOT NULL UNIQUE,
  acei_categories INTEGER[] NOT NULL DEFAULT ARRAY[9, 11],
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_report_fraud_date ON report_fraud_alerts (published_date DESC);

-- 9. Email Security Sweeps (internal infrastructure)
CREATE TABLE email_security_sweeps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sweep_date DATE NOT NULL,
  emails_scanned INTEGER NOT NULL DEFAULT 0,
  threats_detected INTEGER NOT NULL DEFAULT 0,
  threat_details JSONB DEFAULT '[]'::jsonb,
  dmarc_status TEXT,
  spf_status TEXT,
  dkim_status TEXT,
  breach_check_result TEXT,
  alerts_generated INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_email_sweeps_date ON email_security_sweeps (sweep_date DESC);

-- Update calendar status for all sources with tables now deployed
UPDATE intelligence_publication_calendar
SET scraper_status = 'table_deployed', updated_at = now()
WHERE source_code IN (
  'ncsc-alerts-advisories', 'ncsc-news',
  'ico-enforcement-actions', 'ehrc-enforcement',
  'hmrc-nmw-enforcement', 'cert-eu-advisories',
  'govuk-policy-papers', 'mi5-threat-levels',
  'npsa-protective-security', 'nca-fraud-alerts',
  'report-fraud-uk'
)
AND scraper_status = 'pending_build';

