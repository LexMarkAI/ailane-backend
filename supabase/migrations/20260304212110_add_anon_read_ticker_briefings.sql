-- Migration: 20260304212110_add_anon_read_ticker_briefings
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_anon_read_ticker_briefings


CREATE POLICY "Anon can read completed briefings"
  ON public.ticker_briefings FOR SELECT
  TO anon
  USING (generation_status = 'completed' AND quality_passed = true);

