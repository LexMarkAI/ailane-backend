-- AILANE-CC-BRIEF-CASELAW-MIGRATION-001 Phase 1
-- Authority: AMD-111 (proposed) operative under AILANE-LEGAL-MEMO-LICENSING-001 v1.0.
-- Sister specification: AMD-112 (AILANE-SPEC-DPLA-001 v1.0 Cornerstone candidate).
-- Purpose: Add Crown-source URL columns to kl_cases; create per-row migration audit table;
--          snapshot current bailii_url state for 12-month rollback window.
-- Pre-flight verified 2026-04-29 (CC):
--   * 5 new columns absent from kl_cases
--   * kl_cases row count = 255 (matches brief §0 ground truth, 0 drift)
--   * BAILII distribution exact match: 222 TRUE_BAILII / 11 ECHR / 3 EUR-Lex / 2 CJEU / 1 EU Commission
--                                       / 2 supremecourt.uk / 1 parliament.uk / 2 ICO / 8 N/A / 3 NULL
--   * eat_case_law.bailii_url populated count = 0 / 2,524 (halt trigger #2 cleared)
--   * Edge Function dependency scan grep supabase/functions/ — 0 matches (halt trigger #3 cleared)

-- 1. Add five new URL columns to kl_cases (all nullable)
ALTER TABLE public.kl_cases
  ADD COLUMN IF NOT EXISTS tna_url            text NULL,
  ADD COLUMN IF NOT EXISTS judiciary_url      text NULL,
  ADD COLUMN IF NOT EXISTS supremecourt_url   text NULL,
  ADD COLUMN IF NOT EXISTS citation_canonical text NULL,
  ADD COLUMN IF NOT EXISTS url_source_class   text NULL;

-- 2. CHECK constraint on url_source_class (canonical taxonomy per memo §6.6)
ALTER TABLE public.kl_cases
  ADD CONSTRAINT chk_url_source_class CHECK (
    url_source_class IS NULL OR url_source_class IN (
      'crown_tna',                  -- caselaw.nationalarchives.gov.uk
      'crown_supremecourt_uk',      -- supremecourt.uk
      'crown_parliament_uk',        -- publications.parliament.uk archive
      'crown_judiciary_uk',         -- judiciary.uk
      'crown_legislation_uk',       -- legislation.gov.uk (rare for cases)
      'crown_ico',                  -- ico.org.uk enforcement notices
      'citation_only',              -- no Crown URL available; citation_canonical only
      'echr_external',              -- hudoc.echr.coe.int (foreign supranational)
      'cjeu_external',              -- curia.europa.eu (foreign supranational)
      'eurlex_external',            -- eur-lex.europa.eu (foreign supranational)
      'eu_commission_external',     -- ec.europa.eu (foreign)
      'unresolved'                  -- per-row halt: cannot determine class; flagged for Director
    )
  );

-- 3. Per-row migration audit table (append-only)
CREATE TABLE IF NOT EXISTS public.caselaw_migration_audit_log (
  audit_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id           uuid NOT NULL REFERENCES public.kl_cases(case_id) ON DELETE CASCADE,
  migration_phase   text NOT NULL CHECK (migration_phase IN ('phase2_classify','phase3_migrate','phase5_drop')),
  bailii_url_old    text NULL,
  bailii_url_new    text NULL,
  url_source_class  text NULL,
  tna_url           text NULL,
  supremecourt_url  text NULL,
  parliament_url    text NULL,
  judiciary_url     text NULL,
  citation_canonical text NULL,
  head_verification_status text NULL CHECK (head_verification_status IS NULL OR head_verification_status IN ('verified_200','redirect_3xx','client_error_4xx','server_error_5xx','timeout','skipped')),
  rule_applied      text NOT NULL,
  audited_at        timestamptz NOT NULL DEFAULT now(),
  audited_by        text NOT NULL DEFAULT 'cc_migration_agent'
);

CREATE INDEX IF NOT EXISTS idx_caselaw_audit_case_id ON public.caselaw_migration_audit_log(case_id);
CREATE INDEX IF NOT EXISTS idx_caselaw_audit_phase ON public.caselaw_migration_audit_log(migration_phase);

-- 4. RLS — same pattern as kl_cases (service-role write, authenticated read)
ALTER TABLE public.caselaw_migration_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "caselaw_audit_service_write" ON public.caselaw_migration_audit_log
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "caselaw_audit_authenticated_read" ON public.caselaw_migration_audit_log
  FOR SELECT TO authenticated USING (true);

-- 5. Snapshot table — backup of current bailii_url state for 12-month rollback window
--    (per AILANE audit doc §7). Preserves citation + bailii_url as of 2026-04-29.
CREATE TABLE IF NOT EXISTS public.kl_cases_bailii_snapshot_20260429 AS
  SELECT case_id, citation, bailii_url, created_at AS snapshot_taken_at
  FROM public.kl_cases;

ALTER TABLE public.kl_cases_bailii_snapshot_20260429 ADD PRIMARY KEY (case_id);
