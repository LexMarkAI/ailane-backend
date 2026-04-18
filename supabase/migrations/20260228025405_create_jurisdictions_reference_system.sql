-- Migration: 20260228025405_create_jurisdictions_reference_system
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_jurisdictions_reference_system


-- ═══════════════════════════════════════════════════════════════
-- LAYER 1: JURISDICTIONS REFERENCE SYSTEM
-- Constitutional Authority: ACEI Art VIII, RRI Art III §3.6
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS jurisdictions (
  code VARCHAR(10) PRIMARY KEY,
  name TEXT NOT NULL,
  parent_code VARCHAR(10) REFERENCES jurisdictions(code),
  level SMALLINT NOT NULL DEFAULT 0,
  iso_alpha2 CHAR(2) NOT NULL,
  legal_system TEXT,
  employment_law_family TEXT,
  currency_code CHAR(3),
  timezone TEXT,
  acei_jm_base NUMERIC(4,2),
  data_status TEXT NOT NULL DEFAULT 'planned' CHECK (data_status IN ('active','beta','planned','deprecated')),
  activated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_jurisdictions_parent ON jurisdictions(parent_code);
CREATE INDEX idx_jurisdictions_iso ON jurisdictions(iso_alpha2);
CREATE INDEX idx_jurisdictions_status ON jurisdictions(data_status);

-- ── SEED DATA ──────────────────────────────────────────────────

-- UK (active)
INSERT INTO jurisdictions (code, name, parent_code, level, iso_alpha2, legal_system, employment_law_family, currency_code, timezone, acei_jm_base, data_status, activated_at) VALUES
('GB',     'United Kingdom',    NULL, 0, 'GB', 'common_law', 'uk_statutory',       'GBP', 'Europe/London',         1.00, 'active', now()),
('GB-ENG', 'England',           'GB', 1, 'GB', 'common_law', 'uk_statutory',       'GBP', 'Europe/London',         1.05, 'active', now()),
('GB-SCT', 'Scotland',          'GB', 1, 'GB', 'mixed',      'uk_statutory',       'GBP', 'Europe/London',         1.20, 'active', now()),
('GB-WLS', 'Wales',             'GB', 1, 'GB', 'common_law', 'uk_statutory',       'GBP', 'Europe/London',         1.00, 'active', now()),
('GB-NIR', 'Northern Ireland',  'GB', 1, 'GB', 'common_law', 'uk_statutory',       'GBP', 'Europe/London',         1.15, 'active', now()),
-- UK Regions (Level 2)
('GB-LDN', 'London',            'GB-ENG', 2, 'GB', 'common_law', 'uk_statutory',   'GBP', 'Europe/London',         1.40, 'active', now()),
('GB-SE',  'South East England','GB-ENG', 2, 'GB', 'common_law', 'uk_statutory',   'GBP', 'Europe/London',         1.25, 'active', now()),
('GB-NW',  'North West England','GB-ENG', 2, 'GB', 'common_law', 'uk_statutory',   'GBP', 'Europe/London',         1.10, 'active', now()),

-- Ireland (planned → beta soon)
('IE',     'Ireland',           NULL, 0, 'IE', 'common_law', 'irish_statutory',    'EUR', 'Europe/Dublin',         NULL, 'planned', NULL),

-- Australia
('AU',     'Australia',         NULL, 0, 'AU', 'common_law', 'aus_fair_work',      'AUD', 'Australia/Sydney',      NULL, 'planned', NULL),
('AU-FED', 'Australia Federal', 'AU', 1, 'AU', 'common_law', 'aus_fair_work',      'AUD', 'Australia/Sydney',      NULL, 'planned', NULL),
('AU-NSW', 'New South Wales',   'AU', 1, 'AU', 'common_law', 'aus_fair_work',      'AUD', 'Australia/Sydney',      NULL, 'planned', NULL),
('AU-VIC', 'Victoria',          'AU', 1, 'AU', 'common_law', 'aus_fair_work',      'AUD', 'Australia/Melbourne',   NULL, 'planned', NULL),
('AU-QLD', 'Queensland',        'AU', 1, 'AU', 'common_law', 'aus_fair_work',      'AUD', 'Australia/Brisbane',    NULL, 'planned', NULL),

-- New Zealand
('NZ',     'New Zealand',       NULL, 0, 'NZ', 'common_law', 'nz_employment',      'NZD', 'Pacific/Auckland',      NULL, 'planned', NULL),

-- Singapore
('SG',     'Singapore',         NULL, 0, 'SG', 'common_law', 'sg_employment',      'SGD', 'Asia/Singapore',        NULL, 'planned', NULL),

-- United States (tiered)
('US',     'United States',     NULL, 0, 'US', 'common_law', 'us_federal_state',   'USD', 'America/New_York',      NULL, 'planned', NULL),
('US-FED', 'US Federal',        'US', 1, 'US', 'common_law', 'us_federal_state',   'USD', 'America/New_York',      NULL, 'planned', NULL),
('US-CA',  'California',        'US', 1, 'US', 'common_law', 'us_federal_state',   'USD', 'America/Los_Angeles',   NULL, 'planned', NULL),
('US-NY',  'New York',          'US', 1, 'US', 'common_law', 'us_federal_state',   'USD', 'America/New_York',      NULL, 'planned', NULL),
('US-TX',  'Texas',             'US', 1, 'US', 'common_law', 'us_federal_state',   'USD', 'America/Chicago',       NULL, 'planned', NULL),
('US-FL',  'Florida',           'US', 1, 'US', 'common_law', 'us_federal_state',   'USD', 'America/New_York',      NULL, 'planned', NULL),
('US-IL',  'Illinois',          'US', 1, 'US', 'common_law', 'us_federal_state',   'USD', 'America/Chicago',       NULL, 'planned', NULL),

-- Canada
('CA',     'Canada',            NULL, 0, 'CA', 'common_law', 'ca_employment',      'CAD', 'America/Toronto',       NULL, 'planned', NULL),
('CA-FED', 'Canada Federal',    'CA', 1, 'CA', 'common_law', 'ca_employment',      'CAD', 'America/Toronto',       NULL, 'planned', NULL),
('CA-ON',  'Ontario',           'CA', 1, 'CA', 'common_law', 'ca_employment',      'CAD', 'America/Toronto',       NULL, 'planned', NULL),
('CA-BC',  'British Columbia',  'CA', 1, 'CA', 'common_law', 'ca_employment',      'CAD', 'America/Vancouver',     NULL, 'planned', NULL),

-- EU / Europe
('DE',     'Germany',           NULL, 0, 'DE', 'civil_law',  'eu_directive',        'EUR', 'Europe/Berlin',         NULL, 'planned', NULL),
('FR',     'France',            NULL, 0, 'FR', 'civil_law',  'eu_directive',        'EUR', 'Europe/Paris',          NULL, 'planned', NULL),
('NL',     'Netherlands',       NULL, 0, 'NL', 'civil_law',  'eu_directive',        'EUR', 'Europe/Amsterdam',      NULL, 'planned', NULL),

-- Asia-Pacific
('HK',     'Hong Kong',         NULL, 0, 'HK', 'common_law', 'hk_employment',      'HKD', 'Asia/Hong_Kong',        NULL, 'planned', NULL),
('JP',     'Japan',             NULL, 0, 'JP', 'civil_law',  'jp_labour',           'JPY', 'Asia/Tokyo',            NULL, 'planned', NULL),
('IN',     'India',             NULL, 0, 'IN', 'common_law', 'in_labour',           'INR', 'Asia/Kolkata',          NULL, 'planned', NULL),

-- Middle East
('AE',     'UAE',               NULL, 0, 'AE', 'civil_law',  'ae_labour',           'AED', 'Asia/Dubai',            NULL, 'planned', NULL),
('AE-DXB', 'Dubai',             'AE', 1, 'AE', 'civil_law',  'ae_labour',           'AED', 'Asia/Dubai',            NULL, 'planned', NULL),
('AE-DIFC','DIFC',              'AE', 1, 'AE', 'common_law', 'ae_labour',           'AED', 'Asia/Dubai',            NULL, 'planned', NULL),

-- Africa
('ZA',     'South Africa',      NULL, 0, 'ZA', 'mixed',      'za_labour',           'ZAR', 'Africa/Johannesburg',   NULL, 'planned', NULL),
('NG',     'Nigeria',           NULL, 0, 'NG', 'common_law', 'ng_labour',           'NGN', 'Africa/Lagos',          NULL, 'planned', NULL),
('KE',     'Kenya',             NULL, 0, 'KE', 'common_law', 'ke_labour',           'KES', 'Africa/Nairobi',        NULL, 'planned', NULL);

-- Enable RLS
ALTER TABLE jurisdictions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "jurisdictions_public_read" ON jurisdictions FOR SELECT USING (true);
