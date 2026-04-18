-- Migration: 20260417210319_gnyo_001_ticker_briefings_source_table_extend
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: gnyo_001_ticker_briefings_source_table_extend

-- AILANE-CC-BRIEF-GNYO-001-P0a-v2 — Amendment 2
-- Extends ticker_briefings.source_table CHECK to admit the two intelligence
-- source tables used by pipeline-ticker-parliamentary v15+.
-- Legacy values retained for audit continuity.

ALTER TABLE public.ticker_briefings
  DROP CONSTRAINT IF EXISTS ticker_briefings_source_table_check;

ALTER TABLE public.ticker_briefings
  ADD CONSTRAINT ticker_briefings_source_table_check
  CHECK (source_table = ANY (ARRAY[
    'tribunal_decisions'::text,
    'legislative_changes'::text,
    'enforcement_events_unified'::text,
    'parliamentary_intelligence'::text,
    'govuk_news_intelligence'::text
  ]));
