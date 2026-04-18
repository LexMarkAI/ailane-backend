-- Migration: 20260303181003_rls_lockdown_fix_function_search_paths
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: rls_lockdown_fix_function_search_paths


-- ============================================================
-- AILANE RLS LOCKDOWN — MIGRATION 3 OF 3
-- Pin search_path on all public functions to prevent hijacking
-- ============================================================

-- ── 1. update_updated_at_column ─────────────────────────────
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $function$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$function$;

-- ── 2. get_pending_employers_by_priority ────────────────────
CREATE OR REPLACE FUNCTION public.get_pending_employers_by_priority(p_limit integer DEFAULT 500)
RETURNS TABLE(id uuid, raw_name text, normalised_name text)
LANGUAGE sql
STABLE
SET search_path = public
AS $function$
  SELECT em.id, em.raw_name, em.normalised_name
  FROM employer_master em
  LEFT JOIN employer_tribunal_profile etp ON etp.employer_id = em.id
  WHERE em.ch_fetch_status = 'pending'
  ORDER BY 
    CASE WHEN em.raw_name ~* '\m(Ltd|Limited|PLC|LLP)\M' THEN 0 ELSE 1 END,
    COALESCE(etp.aps_total, 0) DESC,
    COALESCE(etp.total_decisions, 0) DESC
  LIMIT p_limit;
$function$;

-- ── 3. get_enrichment_stats ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_enrichment_stats()
RETURNS TABLE(status text, count bigint, pct numeric)
LANGUAGE sql
STABLE
SET search_path = public
AS $function$
  WITH totals AS (
    SELECT COUNT(*) as total FROM employer_master
  )
  SELECT 
    ch_fetch_status as status,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / (SELECT total FROM totals), 1) as pct
  FROM employer_master
  GROUP BY ch_fetch_status
  ORDER BY count DESC;
$function$;

