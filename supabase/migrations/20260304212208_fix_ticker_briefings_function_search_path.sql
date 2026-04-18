-- Migration: 20260304212208_fix_ticker_briefings_function_search_path
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_ticker_briefings_function_search_path


CREATE OR REPLACE FUNCTION update_ticker_briefings_timestamp()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

