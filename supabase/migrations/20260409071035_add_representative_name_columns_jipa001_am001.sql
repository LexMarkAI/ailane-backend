-- Migration: 20260409071035_add_representative_name_columns_jipa001_am001
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_representative_name_columns_jipa001_am001


-- AILANE-SPEC-JIPA-001-AM-001: Representative Intelligence Columns
-- Source: AELIA Representative Intelligence Architecture
-- Purpose: Enable named representative extraction for JIPA Domain 5 
--          Representation Impact Architecture and AELIA Awards
-- Total new columns: 10 (5 per side × 2 sides)
-- Post-migration column count: 166

-- ============================================================
-- CLAIMANT REPRESENTATIVE IDENTITY (5 columns)
-- ============================================================

-- Named individual representing the claimant as stated in judgment header
-- e.g. "Mr J Smith", "Ms K Patel KC", "Employment Judge [name]" 
ALTER TABLE public.tribunal_enrichment 
ADD COLUMN IF NOT EXISTS claimant_rep_name text;

COMMENT ON COLUMN public.tribunal_enrichment.claimant_rep_name IS 
'Named individual representing the claimant as stated in judgment header. Extract verbatim from "For the Claimant:" section. NULL if self-represented or not stated. JIPA-001-AM-001.';

-- Firm, chambers, or organisation of claimant representative
-- e.g. "Old Square Chambers", "Lewis Silkin LLP", "Unite the Union"
ALTER TABLE public.tribunal_enrichment 
ADD COLUMN IF NOT EXISTS claimant_rep_firm text;

COMMENT ON COLUMN public.tribunal_enrichment.claimant_rep_firm IS 
'Firm, chambers, trade union, or organisation of claimant representative. Extract from "instructed by" or "of" designation. NULL if not stated. JIPA-001-AM-001.';

-- Seniority indicator for claimant representative
ALTER TABLE public.tribunal_enrichment 
ADD COLUMN IF NOT EXISTS claimant_rep_seniority text;

ALTER TABLE public.tribunal_enrichment 
ADD CONSTRAINT tribunal_enrichment_claimant_rep_seniority_check 
CHECK (claimant_rep_seniority IS NULL OR claimant_rep_seniority IN (
  'kc', 'senior_counsel', 'junior_counsel', 'senior_solicitor', 
  'solicitor', 'junior_solicitor', 'trainee_solicitor', 
  'legal_executive', 'paralegal', 'trade_union_official', 
  'lay_representative', 'other', 'unknown'
));

COMMENT ON COLUMN public.tribunal_enrichment.claimant_rep_seniority IS 
'Seniority level of claimant representative. KC/QC → kc. Barrister without KC → junior_counsel. Senior solicitor/partner → senior_solicitor. CHECK constraint enforced. JIPA-001-AM-001.';

-- BSB or SRA regulatory ID if stated in judgment (rare but valuable)
ALTER TABLE public.tribunal_enrichment 
ADD COLUMN IF NOT EXISTS claimant_rep_regulatory_id text;

COMMENT ON COLUMN public.tribunal_enrichment.claimant_rep_regulatory_id IS 
'BSB (Bar Standards Board) or SRA (Solicitors Regulation Authority) number if stated in judgment. Extremely rare in ET decisions — extract only when explicitly present. NULL otherwise. JIPA-001-AM-001.';

-- Instructing solicitor name/firm when counsel instructed separately
-- Tribunal headers often state: "Mr X, Counsel, instructed by Y Solicitors"
ALTER TABLE public.tribunal_enrichment 
ADD COLUMN IF NOT EXISTS claimant_rep_instructing_solicitor text;

COMMENT ON COLUMN public.tribunal_enrichment.claimant_rep_instructing_solicitor IS 
'Instructing solicitor name or firm when the claimant is represented by counsel instructed by a separate solicitor. Extract from "instructed by" wording. NULL if not applicable. JIPA-001-AM-001.';

-- ============================================================
-- RESPONDENT REPRESENTATIVE IDENTITY (5 columns)
-- ============================================================

-- Named individual representing the respondent
ALTER TABLE public.tribunal_enrichment 
ADD COLUMN IF NOT EXISTS respondent_rep_name text;

COMMENT ON COLUMN public.tribunal_enrichment.respondent_rep_name IS 
'Named individual representing the respondent as stated in judgment header. Extract verbatim from "For the Respondent:" section. NULL if self-represented or not stated. JIPA-001-AM-001.';

-- Firm, chambers, or organisation of respondent representative
ALTER TABLE public.tribunal_enrichment 
ADD COLUMN IF NOT EXISTS respondent_rep_firm text;

COMMENT ON COLUMN public.tribunal_enrichment.respondent_rep_firm IS 
'Firm, chambers, or organisation of respondent representative. Extract from "instructed by" or "of" designation. NULL if not stated. JIPA-001-AM-001.';

-- Seniority indicator for respondent representative
ALTER TABLE public.tribunal_enrichment 
ADD COLUMN IF NOT EXISTS respondent_rep_seniority text;

ALTER TABLE public.tribunal_enrichment 
ADD CONSTRAINT tribunal_enrichment_respondent_rep_seniority_check 
CHECK (respondent_rep_seniority IS NULL OR respondent_rep_seniority IN (
  'kc', 'senior_counsel', 'junior_counsel', 'senior_solicitor', 
  'solicitor', 'junior_solicitor', 'trainee_solicitor', 
  'legal_executive', 'paralegal', 'hr_professional',
  'in_house_counsel', 'lay_representative', 'other', 'unknown'
));

COMMENT ON COLUMN public.tribunal_enrichment.respondent_rep_seniority IS 
'Seniority level of respondent representative. Note: respondent-side includes hr_professional and in_house_counsel values not available on claimant side. CHECK constraint enforced. JIPA-001-AM-001.';

-- BSB or SRA regulatory ID if stated
ALTER TABLE public.tribunal_enrichment 
ADD COLUMN IF NOT EXISTS respondent_rep_regulatory_id text;

COMMENT ON COLUMN public.tribunal_enrichment.respondent_rep_regulatory_id IS 
'BSB or SRA number if stated in judgment. Extremely rare — extract only when explicitly present. NULL otherwise. JIPA-001-AM-001.';

-- Instructing solicitor for respondent counsel
ALTER TABLE public.tribunal_enrichment 
ADD COLUMN IF NOT EXISTS respondent_rep_instructing_solicitor text;

COMMENT ON COLUMN public.tribunal_enrichment.respondent_rep_instructing_solicitor IS 
'Instructing solicitor name or firm when the respondent is represented by counsel instructed by a separate solicitor. Extract from "instructed by" wording. NULL if not applicable. JIPA-001-AM-001.';

-- ============================================================
-- INDEXES for representative intelligence queries
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_tribunal_enrichment_claimant_rep_name 
ON public.tribunal_enrichment (claimant_rep_name) WHERE claimant_rep_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tribunal_enrichment_claimant_rep_firm 
ON public.tribunal_enrichment (claimant_rep_firm) WHERE claimant_rep_firm IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tribunal_enrichment_respondent_rep_name 
ON public.tribunal_enrichment (respondent_rep_name) WHERE respondent_rep_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tribunal_enrichment_respondent_rep_firm 
ON public.tribunal_enrichment (respondent_rep_firm) WHERE respondent_rep_firm IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tribunal_enrichment_claimant_rep_seniority 
ON public.tribunal_enrichment (claimant_rep_seniority) WHERE claimant_rep_seniority IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tribunal_enrichment_respondent_rep_seniority 
ON public.tribunal_enrichment (respondent_rep_seniority) WHERE respondent_rep_seniority IS NOT NULL;

-- Composite indexes for AELIA representative profiling queries
CREATE INDEX IF NOT EXISTS idx_tribunal_enrichment_claimant_rep_profile
ON public.tribunal_enrichment (claimant_rep_name, claimant_rep_firm, claimant_rep_type)
WHERE claimant_rep_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tribunal_enrichment_respondent_rep_profile
ON public.tribunal_enrichment (respondent_rep_name, respondent_rep_firm, respondent_rep_type)
WHERE respondent_rep_name IS NOT NULL;

-- Composite indexes for dual-side practitioner detection (AELIA Dual-Side Master)
CREATE INDEX IF NOT EXISTS idx_tribunal_enrichment_dual_side_claimant
ON public.tribunal_enrichment (claimant_rep_name, outcome) WHERE claimant_rep_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tribunal_enrichment_dual_side_respondent
ON public.tribunal_enrichment (respondent_rep_name, outcome) WHERE respondent_rep_name IS NOT NULL;

