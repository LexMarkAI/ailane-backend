-- Migration: 20260228015337_fix_function_search_paths
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_function_search_paths


-- ================================================================
-- FIX: Function search_path mutable warnings
-- Sets explicit search_path to prevent schema injection attacks
-- ================================================================

ALTER FUNCTION public.compute_evi(text, date) SET search_path = public;
ALTER FUNCTION public.compute_eii(text, date) SET search_path = public;
ALTER FUNCTION public.compute_sci(text, date) SET search_path = public;
ALTER FUNCTION public.recompute_acei_scores(date, uuid) SET search_path = public;
