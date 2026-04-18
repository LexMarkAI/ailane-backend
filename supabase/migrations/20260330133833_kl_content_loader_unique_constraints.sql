-- Migration: 20260330133833_kl_content_loader_unique_constraints
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: kl_content_loader_unique_constraints


-- ============================================================================
-- kl_content_loader_unique_constraints
-- Required by CC-BRIEF-KL-CONTENT-LOADER §3
-- Enables UPSERT (INSERT ON CONFLICT) for the content loader
-- ============================================================================

-- Unique constraint for provision upsert: one provision per instrument + section
ALTER TABLE public.kl_provisions
  ADD CONSTRAINT kl_provisions_instrument_section_unique
  UNIQUE (instrument_id, section_num);

-- Unique constraint for case upsert: citation is the natural key
ALTER TABLE public.kl_cases
  ADD CONSTRAINT kl_cases_citation_unique
  UNIQUE (citation);

-- Add governance comments
COMMENT ON CONSTRAINT kl_provisions_instrument_section_unique ON public.kl_provisions
  IS 'KLIA-001: One provision row per instrument + section_num combination. Enables content loader UPSERT.';
COMMENT ON CONSTRAINT kl_cases_citation_unique ON public.kl_cases
  IS 'KLIA-001: Citation is the natural key for cases. Enables content loader UPSERT.';

