-- Migration: 20260307035417_index_tribunal_decisions_enrichment_lookup
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: index_tribunal_decisions_enrichment_lookup


-- Index to speed up enrich_tribunals.py timeout issue
CREATE INDEX IF NOT EXISTS idx_tribunal_decisions_processing_status 
ON tribunal_decisions(processing_status) 
WHERE processing_status IS NULL OR processing_status NOT IN ('enriched','reclassified','enriched_no_jcode');

-- Index to speed up deep enrichment pending lookup
CREATE INDEX IF NOT EXISTS idx_tribunal_decisions_pdf_urls_not_null
ON tribunal_decisions(decision_date DESC)
WHERE pdf_urls IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tribunal_enrichment_decision_id
ON tribunal_enrichment(decision_id);

