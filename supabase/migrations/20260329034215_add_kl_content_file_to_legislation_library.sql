-- Migration: 20260329034215_add_kl_content_file_to_legislation_library
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_kl_content_file_to_legislation_library


-- Add KL content file mapping to legislation_library
-- Links registry entries to their enriched JSON content files at /knowledge-library/content/
ALTER TABLE public.legislation_library 
  ADD COLUMN IF NOT EXISTS kl_content_file TEXT,
  ADD COLUMN IF NOT EXISTS kl_content_version TEXT DEFAULT '1.0',
  ADD COLUMN IF NOT EXISTS kl_enriched_at TIMESTAMPTZ;

COMMENT ON COLUMN public.legislation_library.kl_content_file IS 'JSON filename in /knowledge-library/content/ (e.g. era1996). NULL = no deep content file. Governed by KLIA-001.';
COMMENT ON COLUMN public.legislation_library.kl_content_version IS 'Content version of the KL JSON file. Tracks enrichment state. 1.1 = Stage 3 enriched.';
COMMENT ON COLUMN public.legislation_library.kl_enriched_at IS 'Timestamp of last KL content enrichment.';

