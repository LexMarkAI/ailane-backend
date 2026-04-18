-- Migration: 20260405151013_add_body_type_taxonomy_to_employer_master
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_body_type_taxonomy_to_employer_master


-- Body Type Taxonomy on employer_master
-- Three-tier classification: body_type > body_sub_type > acei_sector (existing)

-- Top-level: public vs private vs third sector
ALTER TABLE public.employer_master 
  ADD COLUMN IF NOT EXISTS body_type text,
  ADD COLUMN IF NOT EXISTS body_sub_type text,
  ADD COLUMN IF NOT EXISTS body_nation text,
  ADD COLUMN IF NOT EXISTS body_classification_method text,
  ADD COLUMN IF NOT EXISTS body_classification_confidence numeric,
  ADD COLUMN IF NOT EXISTS body_classified_at timestamptz;

-- Indexes for analytical queries
CREATE INDEX IF NOT EXISTS idx_employer_master_body_type 
  ON public.employer_master (body_type);
CREATE INDEX IF NOT EXISTS idx_employer_master_body_sub_type 
  ON public.employer_master (body_sub_type);
CREATE INDEX IF NOT EXISTS idx_employer_master_body_nation 
  ON public.employer_master (body_nation);

-- Composite index for category-by-category analysis joins
CREATE INDEX IF NOT EXISTS idx_employer_master_body_taxonomy 
  ON public.employer_master (body_type, body_sub_type, acei_sector);

COMMENT ON COLUMN public.employer_master.body_type IS 'Top-level classification: public_body, private_sector, third_sector, unclassified';
COMMENT ON COLUMN public.employer_master.body_sub_type IS 'Sub-classification: nhs_health, local_authority, police, central_government, university, education_school_college, emergency_services, armed_forces_mod, housing_association, public_corp_devolved, private_company, sole_trader, charity, social_enterprise, etc.';
COMMENT ON COLUMN public.employer_master.body_nation IS 'Nation within UK: england, wales, scotland, northern_ireland, uk_wide, unknown';
COMMENT ON COLUMN public.employer_master.body_classification_method IS 'How classification was determined: sic_code, name_pattern, company_type, manual, composite';
COMMENT ON COLUMN public.employer_master.body_classification_confidence IS 'Confidence score 0.0-1.0 for the classification';
COMMENT ON COLUMN public.employer_master.body_classified_at IS 'Timestamp of last classification run';

