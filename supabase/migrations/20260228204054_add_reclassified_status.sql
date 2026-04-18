-- Migration: 20260228204054_add_reclassified_status
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_reclassified_status


-- Add 'reclassified' and 'enriched' to processing_status constraint
ALTER TABLE tribunal_decisions 
DROP CONSTRAINT tribunal_decisions_processing_status_check;

ALTER TABLE tribunal_decisions 
ADD CONSTRAINT tribunal_decisions_processing_status_check 
CHECK (processing_status = ANY (ARRAY[
  'raw', 'classified', 'verified', 'error', 
  'reclassified', 'enriched', 'enriched_no_jcode', 'enrich_error'
]));

-- Allow category_number 0 for unclassified
ALTER TABLE tribunal_decisions 
DROP CONSTRAINT tribunal_decisions_acei_category_number_check;

ALTER TABLE tribunal_decisions 
ADD CONSTRAINT tribunal_decisions_acei_category_number_check 
CHECK (acei_category_number >= 0 AND acei_category_number <= 12);

