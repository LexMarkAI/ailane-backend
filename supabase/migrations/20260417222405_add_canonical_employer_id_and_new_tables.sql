-- Migration: 20260417222405_add_canonical_employer_id_and_new_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_canonical_employer_id_and_new_tables


-- Add canonical_employer_id to existing tables that lack it
ALTER TABLE public.fos_firm_complaints ADD COLUMN IF NOT EXISTS canonical_employer_id UUID;
ALTER TABLE public.fca_firm_complaints ADD COLUMN IF NOT EXISTS canonical_employer_id UUID;
ALTER TABLE public.tpr_penalty_notices ADD COLUMN IF NOT EXISTS canonical_employer_id UUID;
ALTER TABLE public.tpo_determinations ADD COLUMN IF NOT EXISTS canonical_employer_id UUID;

-- Create indexes on the new columns (IF NOT EXISTS not available for indexes, use safe naming)
CREATE INDEX IF NOT EXISTS idx_fos_canonical ON public.fos_firm_complaints(canonical_employer_id);
CREATE INDEX IF NOT EXISTS idx_fca_comp_canonical ON public.fca_firm_complaints(canonical_employer_id);
CREATE INDEX IF NOT EXISTS idx_tpr_canonical ON public.tpr_penalty_notices(canonical_employer_id);
CREATE INDEX IF NOT EXISTS idx_tpo_canonical ON public.tpo_determinations(canonical_employer_id);

-- Create eat_decisions (does not exist yet)
CREATE TABLE IF NOT EXISTS public.eat_decisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  case_number TEXT,
  decision_date DATE,
  published_date DATE,
  respondent_name TEXT,
  claimant_name TEXT,
  judge_name TEXT,
  appeal_outcome TEXT CHECK (appeal_outcome IN ('allowed','dismissed','allowed_in_part','remitted','withdrawn','unknown')),
  original_et_case_number TEXT,
  original_et_decision_id UUID,
  jurisdiction_codes TEXT[],
  acei_categories TEXT[],
  summary TEXT,
  source_url TEXT NOT NULL,
  pdf_urls TEXT[],
  pdf_extracted_text TEXT,
  pdf_extraction_status TEXT DEFAULT 'pending' CHECK (pdf_extraction_status IN ('pending','complete','failed','skipped')),
  content_hash TEXT,
  scraped_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(source_url)
);
CREATE INDEX IF NOT EXISTS idx_eat_respondent ON public.eat_decisions(respondent_name);
CREATE INDEX IF NOT EXISTS idx_eat_case ON public.eat_decisions(case_number);
CREATE INDEX IF NOT EXISTS idx_eat_date ON public.eat_decisions(published_date);
COMMENT ON TABLE public.eat_decisions IS 'Employment Appeal Tribunal decisions. Source: GOV.UK.';

-- Create fca_enforcement_actions (does not exist yet)
CREATE TABLE IF NOT EXISTS public.fca_enforcement_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_name TEXT NOT NULL,
  firm_name_normalised TEXT,
  canonical_employer_id UUID,
  frn TEXT,
  individual_name TEXT,
  notice_type TEXT NOT NULL CHECK (notice_type IN ('final_notice','decision_notice','supervisory_notice','vreq','s166','other')),
  date_issued DATE NOT NULL,
  penalty_amount_gbp NUMERIC(14,2),
  breach_category TEXT,
  principle_breached TEXT,
  summary TEXT,
  source_url TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(source_url)
);
CREATE INDEX IF NOT EXISTS idx_fca_enf_firm ON public.fca_enforcement_actions(firm_name_normalised);
CREATE INDEX IF NOT EXISTS idx_fca_enf_frn ON public.fca_enforcement_actions(frn);
CREATE INDEX IF NOT EXISTS idx_fca_enf_canonical ON public.fca_enforcement_actions(canonical_employer_id);
COMMENT ON TABLE public.fca_enforcement_actions IS 'FCA Final Notices and enforcement actions. Source: FCA website.';

