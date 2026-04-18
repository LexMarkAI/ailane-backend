-- Migration: 20260307035011_tribunal_enrichment_add_skip_status
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: tribunal_enrichment_add_skip_status


ALTER TABLE tribunal_enrichment 
DROP CONSTRAINT IF EXISTS tribunal_enrichment_scrape_status_check;

ALTER TABLE tribunal_enrichment
ADD CONSTRAINT tribunal_enrichment_scrape_status_check
CHECK (scrape_status = ANY (ARRAY[
  'pending','in_progress','complete','failed','no_document','skip'
]));

-- Mark the stuck Ibrahim record as skip
UPDATE tribunal_enrichment te
SET scrape_status = 'skip',
    scrape_error  = 'LLM malformed JSON - permanently skipped'
FROM tribunal_decisions td
WHERE te.decision_id = td.id
AND td.title LIKE '%Ibrahim%IBC Quality%';

