-- Migration: 20260417205747_gnyo_001_ticker_briefings_context_columns
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: gnyo_001_ticker_briefings_context_columns

-- AILANE-CC-BRIEF-GNYO-001-P0a-v2 — Amendment
-- Adds context columns required by pipeline-ticker-parliamentary upsert.
-- Rationale: brief §6 v13/v12 upsert references columns that were absent
-- from ticker_briefings, causing PGRST204 and silent briefing failure since
-- 2026-03-15. Additive only — no renames, no drops, no consumer breakage.

ALTER TABLE public.ticker_briefings
  ADD COLUMN IF NOT EXISTS acei_category        text,
  ADD COLUMN IF NOT EXISTS event_date           date,
  ADD COLUMN IF NOT EXISTS source_url           text,
  ADD COLUMN IF NOT EXISTS legislative_urgency  text;

COMMENT ON COLUMN public.ticker_briefings.acei_category
  IS 'Primary ACEI category from source row. Written by pipeline-ticker-parliamentary.';
COMMENT ON COLUMN public.ticker_briefings.event_date
  IS 'Event or publication date from source row.';
COMMENT ON COLUMN public.ticker_briefings.source_url
  IS 'Canonical URL of the originating source item.';
COMMENT ON COLUMN public.ticker_briefings.legislative_urgency
  IS 'Urgency marker carried from source for ticker rendering.';
