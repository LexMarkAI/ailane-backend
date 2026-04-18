-- Migration: 20260307002425_pcie_schema_foundation
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: pcie_schema_foundation


-- ============================================================
-- PCIE SCHEMA FOUNDATION
-- AILANE-SPEC-PCIE-003 v3.0 | 7 March 2026
-- Step 1: DDL changes to support Pre-Client Intelligence Environment
-- ============================================================

-- 1. Extend organisations table for PCIE demonstration entity support
ALTER TABLE organisations
  ADD COLUMN IF NOT EXISTS is_demonstration_entity BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS pcie_company_number TEXT,
  ADD COLUMN IF NOT EXISTS registered_address TEXT,
  ADD COLUMN IF NOT EXISTS annual_turnover_band TEXT,
  ADD COLUMN IF NOT EXISTS incorporated_year INTEGER,
  ADD COLUMN IF NOT EXISTS sic_primary TEXT,
  ADD COLUMN IF NOT EXISTS sic_secondary TEXT[],
  ADD COLUMN IF NOT EXISTS operational_sites JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS acei_sector_code TEXT,
  ADD COLUMN IF NOT EXISTS acei_sector_multiplier NUMERIC,
  ADD COLUMN IF NOT EXISTS workforce_jm_weighted NUMERIC;

-- 2. RRI pillar scores per organisation
CREATE TABLE IF NOT EXISTS pcie_rri_pillars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  computation_ref TEXT NOT NULL DEFAULT 'RRI-v1.0',
  computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  week_start_date DATE NOT NULL,
  -- Five constitutional pillars
  pa_score INTEGER NOT NULL CHECK (pa_score BETWEEN 0 AND 5),   -- Policy Alignment
  cc_score INTEGER NOT NULL CHECK (cc_score BETWEEN 0 AND 5),   -- Contractual Conformity
  td_score INTEGER NOT NULL CHECK (td_score BETWEEN 0 AND 5),   -- Training Deployment
  spa_score INTEGER NOT NULL CHECK (spa_score BETWEEN 0 AND 5), -- Systems & Process Adaptation
  go_score INTEGER NOT NULL CHECK (go_score BETWEEN 0 AND 5),   -- Governance Oversight
  -- Pillar Weight Vector (EIP-derived, FM sector)
  pa_weight NUMERIC NOT NULL,
  cc_weight NUMERIC NOT NULL,
  td_weight NUMERIC NOT NULL,
  spa_weight NUMERIC NOT NULL,
  go_weight NUMERIC NOT NULL,
  -- Computed WDRS = Σ(Ps·Pv) × 20
  wdrs NUMERIC NOT NULL,
  -- Pillar findings summary (for UI display)
  pa_finding TEXT,
  cc_finding TEXT,
  td_finding TEXT,
  spa_finding TEXT,
  go_finding TEXT,
  -- Evidence quality
  evidence_quality TEXT NOT NULL DEFAULT 'modelled',
  is_demonstration_data BOOLEAN NOT NULL DEFAULT false,
  constitution_version TEXT NOT NULL DEFAULT 'RRI-v1.0',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pcie_rri_pillars_org_id ON pcie_rri_pillars(org_id);
CREATE INDEX IF NOT EXISTS idx_pcie_rri_pillars_week ON pcie_rri_pillars(week_start_date);

-- 3. CCI conduct events per organisation
CREATE TABLE IF NOT EXISTS pcie_cci_conduct_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  event_year INTEGER NOT NULL,
  event_period TEXT NOT NULL,                         -- e.g. '2023', '2014-2019'
  acei_category TEXT NOT NULL,                        -- links to ACEI category code
  event_description TEXT NOT NULL,
  outcome_type TEXT NOT NULL CHECK (outcome_type IN (
    'tribunal_award', 'settlement', 'conciliation',
    'internal_resolution', 'clean_record', 'investigation_pending'
  )),
  outcome_description TEXT NOT NULL,
  compensation_amount NUMERIC,                         -- GBP where known
  ci_score NUMERIC NOT NULL CHECK (ci_score BETWEEN 0 AND 100), -- component score (low=poor conduct)
  zi_weight NUMERIC NOT NULL CHECK (zi_weight > 0),               -- Bayesian credibility weight
  cci_contribution NUMERIC GENERATED ALWAYS AS (ci_score * zi_weight) STORED,
  recency_band TEXT NOT NULL CHECK (recency_band IN ('recent', 'mid', 'historical', 'baseline')),
  resolution_quality TEXT NOT NULL CHECK (resolution_quality IN (
    'poor', 'partial', 'adequate', 'good', 'excellent'
  )),
  is_demonstration_data BOOLEAN NOT NULL DEFAULT false,
  constitution_version TEXT NOT NULL DEFAULT 'CCI-v1.0',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pcie_cci_events_org_id ON pcie_cci_conduct_events(org_id);

-- 4. CCI aggregate scores per organisation
CREATE TABLE IF NOT EXISTS pcie_cci_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  week_start_date DATE NOT NULL,
  cci NUMERIC NOT NULL CHECK (cci BETWEEN 0 AND 100),       -- CCI = Σ(Ci·Zi) ÷ Σ(Zi)
  total_ci_zi NUMERIC NOT NULL,                              -- Σ(Ci·Zi) numerator
  total_zi NUMERIC NOT NULL,                                 -- Σ(Zi) denominator
  event_count INTEGER NOT NULL,
  sector_median_cci NUMERIC,                                 -- for benchmarking
  conduct_band TEXT NOT NULL CHECK (conduct_band IN (
    'exemplary', 'good', 'developing', 'concerning', 'poor'
  )),
  is_demonstration_data BOOLEAN NOT NULL DEFAULT false,
  constitution_version TEXT NOT NULL DEFAULT 'CCI-v1.0',
  computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pcie_cci_scores_org_id ON pcie_cci_scores(org_id);

-- 5. PCIE demonstration entity registry (maps org_id to PCIE metadata)
CREATE TABLE IF NOT EXISTS pcie_demonstration_entities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL UNIQUE REFERENCES organisations(id) ON DELETE CASCADE,
  entity_ref TEXT NOT NULL,                    -- e.g. 'northerly-hill'
  display_name TEXT NOT NULL,
  fictional_company_number TEXT NOT NULL,      -- NH-2014-0347
  spec_version TEXT NOT NULL DEFAULT 'AILANE-SPEC-PCIE-003-v3.0',
  ratification_date DATE NOT NULL,
  sector_code TEXT NOT NULL,
  headcount INTEGER NOT NULL,
  employee_mix JSONB NOT NULL DEFAULT '{}',
  operational_sites JSONB NOT NULL DEFAULT '[]',
  acei_di INTEGER,
  rri_wdrs NUMERIC,
  cci_score NUMERIC,
  wcc_aggregate NUMERIC,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. REL — Client-Reported Enforcement Events (CREE)
-- Per ACEI-AM-2026-003 v2: all-tier input, six-step irreversible anonymisation
CREATE TABLE IF NOT EXISTS cree_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organisations(id) ON DELETE SET NULL, -- null after anonymisation
  -- Pre-anonymisation fields (client's own record only)
  regulatory_body TEXT NOT NULL,
  contact_type TEXT NOT NULL,
  event_date DATE NOT NULL,                       -- stored as exact date in client record only
  acei_focus_areas TEXT[] NOT NULL DEFAULT '{}',
  outcome TEXT NOT NULL,
  operational_site TEXT,
  narrative TEXT,                                 -- NEVER enters CREE network layer
  -- Post-anonymisation CREE network fields (written after 6-step pipeline)
  anon_sector_code TEXT,                          -- sector code + size band only
  anon_subregion TEXT,                            -- ACEI sub-region centroid
  anon_month_year TEXT,                           -- YYYY-MM precision only
  anon_enforcement_body TEXT,
  anon_outcome_category TEXT,
  anon_processed BOOLEAN NOT NULL DEFAULT false,
  -- Threshold tracking
  threshold_met BOOLEAN NOT NULL DEFAULT false,   -- ≥5 events, ≥3 clients in sub-region×sector×body
  is_demonstration_data BOOLEAN NOT NULL DEFAULT false,
  constitution_version TEXT NOT NULL DEFAULT 'ACEI-AM-2026-003-v2',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cree_submissions_org_id ON cree_submissions(org_id);
CREATE INDEX IF NOT EXISTS idx_cree_submissions_anon ON cree_submissions(anon_subregion, anon_sector_code, anon_enforcement_body) WHERE anon_processed = true;

