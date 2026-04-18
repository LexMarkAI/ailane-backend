-- Migration: 20260307002431_pcie_schema_northerly_hill_foundation
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: pcie_schema_northerly_hill_foundation


-- ============================================================
-- PCIE SCHEMA FOUNDATION
-- AILANE-SPEC-PCIE-003 v3.0 · 7 March 2026
-- Constitutional basis: ACEI v1.0 · RRI v1.0 · CCI v1.0
-- ============================================================

-- 1. Add demonstration entity flag to organisations
ALTER TABLE organisations 
  ADD COLUMN IF NOT EXISTS is_demonstration_entity BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS sic_primary TEXT,
  ADD COLUMN IF NOT EXISTS sic_secondary TEXT[],
  ADD COLUMN IF NOT EXISTS registered_address TEXT,
  ADD COLUMN IF NOT EXISTS operational_sites JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS annual_turnover_band TEXT,
  ADD COLUMN IF NOT EXISTS incorporated_year INTEGER,
  ADD COLUMN IF NOT EXISTS fictional_company_number TEXT,
  ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT,
  ADD COLUMN IF NOT EXISTS stripe_subscription_id TEXT,
  ADD COLUMN IF NOT EXISTS tier TEXT DEFAULT 'operational_readiness';

-- 2. RRI Scores table — governs Regulatory Readiness Index storage
-- Formula: WDRS = Σ(PillarScore_p × PWV_p) × 20 | Article VI §6.5
CREATE TABLE IF NOT EXISTS rri_scores (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id              UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  computed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  wdrs                NUMERIC(5,1) NOT NULL CHECK (wdrs >= 0 AND wdrs <= 100),
  -- Pillar scores (0–5 scale, evidence-adjusted)
  pa_score            NUMERIC(4,2) NOT NULL,
  cc_score            NUMERIC(4,2) NOT NULL,
  td_score            NUMERIC(4,2) NOT NULL,
  spa_score           NUMERIC(4,2) NOT NULL,
  go_score            NUMERIC(4,2) NOT NULL,
  -- Pillar Weight Vector (sums to 1.0, bounds [0.10, 0.35])
  pa_pwv              NUMERIC(5,3) NOT NULL,
  cc_pwv              NUMERIC(5,3) NOT NULL,
  td_pwv              NUMERIC(5,3) NOT NULL,
  spa_pwv             NUMERIC(5,3) NOT NULL,
  go_pwv              NUMERIC(5,3) NOT NULL,
  -- WCC aggregate (from Document Intelligence Vault)
  wcc_aggregate       NUMERIC(5,2),
  constitution_version TEXT NOT NULL DEFAULT 'RRI-v1.0',
  computation_notes   TEXT,
  is_demonstration    BOOLEAN NOT NULL DEFAULT false,
  metadata            JSONB DEFAULT '{}',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rri_pwv_sum CHECK (
    ABS((pa_pwv + cc_pwv + td_pwv + spa_pwv + go_pwv) - 1.0) < 0.001
  ),
  CONSTRAINT rri_pillar_bounds CHECK (
    pa_pwv BETWEEN 0.10 AND 0.35 AND
    cc_pwv BETWEEN 0.10 AND 0.35 AND
    td_pwv BETWEEN 0.10 AND 0.35 AND
    spa_pwv BETWEEN 0.10 AND 0.35 AND
    go_pwv BETWEEN 0.10 AND 0.35
  )
);

-- 3. CCI Scores table — governs Compliance Conduct Index storage
-- Formula: CCI = Σ(Ci·Zi) ÷ Σ(Zi) | CCI Constitution v1.0
CREATE TABLE IF NOT EXISTS cci_scores (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id              UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  computed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  cci                 NUMERIC(5,1) NOT NULL CHECK (cci >= 0 AND cci <= 100),
  -- Components stored as structured JSONB array
  -- Schema: [{name, ci, zi, label, year, outcome}]
  components          JSONB NOT NULL DEFAULT '[]',
  constitution_version TEXT NOT NULL DEFAULT 'CCI-v1.0',
  computation_notes   TEXT,
  is_demonstration    BOOLEAN NOT NULL DEFAULT false,
  metadata            JSONB DEFAULT '{}',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Workforce Contract records — feeds RRI Contractual Conformity pillar
-- Extends compliance_uploads with role weighting for WCC computation
CREATE TABLE IF NOT EXISTS vault_contract_records (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id              UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  upload_id           UUID REFERENCES compliance_uploads(id) ON DELETE SET NULL,
  employee_ref        TEXT NOT NULL,         -- e.g. NHF-DIR-001
  role_title          TEXT NOT NULL,
  role_tier           TEXT NOT NULL CHECK (role_tier IN ('director','senior_mgmt','management','admin','operative')),
  tier_weight         INTEGER NOT NULL CHECK (tier_weight IN (1,2,3,4)),
  compliance_score    NUMERIC(5,2) NOT NULL CHECK (compliance_score >= 0 AND compliance_score <= 100),
  critical_gaps       INTEGER NOT NULL DEFAULT 0,
  key_finding         TEXT,
  -- PII isolation: name never stored here — resolved at presentation layer only
  is_demonstration    BOOLEAN NOT NULL DEFAULT false,
  metadata            JSONB DEFAULT '{}',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, employee_ref)
);

-- 5. PCIE audit log — records all demonstration tier views for governance
CREATE TABLE IF NOT EXISTS pcie_session_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id  TEXT NOT NULL,
  tier_viewed TEXT NOT NULL,
  org_id      UUID REFERENCES organisations(id),
  ip_hash     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_rri_scores_org_id ON rri_scores(org_id);
CREATE INDEX IF NOT EXISTS idx_cci_scores_org_id ON cci_scores(org_id);
CREATE INDEX IF NOT EXISTS idx_vault_contract_records_org_id ON vault_contract_records(org_id);
CREATE INDEX IF NOT EXISTS idx_organisations_demo ON organisations(is_demonstration_entity);

