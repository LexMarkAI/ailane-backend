-- Migration: 20260307174641_replace_get_enrichment_stats_rpc
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: replace_get_enrichment_stats_rpc


DROP FUNCTION IF EXISTS get_enrichment_stats();

CREATE FUNCTION get_enrichment_stats()
RETURNS TABLE(ch_fetch_status TEXT, count BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT ch_fetch_status, COUNT(*) AS count
  FROM employer_master
  GROUP BY ch_fetch_status
  ORDER BY count DESC;
$$;

