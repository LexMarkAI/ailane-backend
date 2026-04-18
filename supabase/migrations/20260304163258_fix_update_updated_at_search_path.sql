-- Migration: 20260304163258_fix_update_updated_at_search_path
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_update_updated_at_search_path


-- Fix mutable search_path on update_updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

