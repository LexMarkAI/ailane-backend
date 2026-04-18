-- Migration: 20260307040723_index_for_stage2_pdf_urls_null
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: index_for_stage2_pdf_urls_null


-- Index specifically for stage 2 query pattern: pdf_urls IS NULL with source_url present
CREATE INDEX IF NOT EXISTS idx_tribunal_decisions_no_pdf
ON tribunal_decisions(decision_date DESC)
WHERE pdf_urls IS NULL AND source_url IS NOT NULL;

-- Also increase statement timeout for this session type
ALTER DATABASE postgres SET statement_timeout = '120s';

