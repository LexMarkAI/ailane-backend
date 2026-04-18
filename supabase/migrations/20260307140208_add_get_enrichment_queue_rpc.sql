-- Migration: 20260307140208_add_get_enrichment_queue_rpc
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_get_enrichment_queue_rpc


-- ═══════════════════════════════════════════════════════════════════════
-- AILANE · get_enrichment_queue RPC
-- Returns employers ordered by claim count (highest first) for each mode
-- Called by ch_enrichment_scraper_v2.py
-- ═══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION get_enrichment_queue(
  p_mode  TEXT,
  p_limit INT DEFAULT 500
)
RETURNS TABLE (
  id               UUID,
  raw_name         TEXT,
  normalised_name  TEXT,
  ch_fetch_status  TEXT,
  claim_count      BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    em.id,
    em.raw_name,
    em.normalised_name,
    em.ch_fetch_status,
    COUNT(edl.id) AS claim_count
  FROM employer_master em
  LEFT JOIN employer_decision_link edl ON edl.employer_id = em.id
  WHERE
    CASE p_mode
      WHEN 'priority'  THEN em.ch_fetch_status IN ('not_found','error','low_confidence')
      WHEN 'errors'    THEN em.ch_fetch_status = 'error'
      WHEN 'low_conf'  THEN em.ch_fetch_status = 'low_confidence'
      WHEN 'bulk'      THEN em.ch_fetch_status = 'not_found'
      ELSE em.ch_fetch_status IN ('not_found','error','low_confidence')
    END
    AND em.ch_fetch_status NOT IN (
      'skipped_individual','skipped_insufficient_name',
      'skipped_statutory','statutory_body_seeded'
    )
  GROUP BY em.id, em.raw_name, em.normalised_name, em.ch_fetch_status
  ORDER BY claim_count DESC, em.ch_last_fetched ASC NULLS FIRST
  LIMIT p_limit;
$$;

-- Grant to service_role only — scraper uses service key
GRANT EXECUTE ON FUNCTION get_enrichment_queue(TEXT, INT) TO service_role;
REVOKE EXECUTE ON FUNCTION get_enrichment_queue(TEXT, INT) FROM PUBLIC, anon, authenticated;

