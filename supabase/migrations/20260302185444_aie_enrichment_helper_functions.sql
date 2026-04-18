-- Migration: 20260302185444_aie_enrichment_helper_functions
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: aie_enrichment_helper_functions


-- AIE Helper Function: Get pending employers ordered by priority
-- Company-suffix names first (highest CH match probability),
-- then sorted by APS score (highest commercial value first)
CREATE OR REPLACE FUNCTION get_pending_employers_by_priority(p_limit integer DEFAULT 500)
RETURNS TABLE(id uuid, raw_name text, normalised_name text)
LANGUAGE sql STABLE
AS $$
  SELECT em.id, em.raw_name, em.normalised_name
  FROM employer_master em
  LEFT JOIN employer_tribunal_profile etp ON etp.employer_id = em.id
  WHERE em.ch_fetch_status = 'pending'
  ORDER BY 
    -- Priority 1: Company suffix names (highest match probability)
    CASE WHEN em.raw_name ~* '\m(Ltd|Limited|PLC|LLP)\M' THEN 0 ELSE 1 END,
    -- Priority 2: Highest APS score (most commercially valuable)
    COALESCE(etp.aps_total, 0) DESC,
    -- Priority 3: Most tribunal decisions (strongest signal)
    COALESCE(etp.total_decisions, 0) DESC
  LIMIT p_limit;
$$;

-- AIE Helper Function: Get enrichment progress statistics
CREATE OR REPLACE FUNCTION get_enrichment_stats()
RETURNS TABLE(
  status text,
  count bigint,
  pct numeric
)
LANGUAGE sql STABLE
AS $$
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
$$;

-- AIE Helper View: Enrichment dashboard summary
CREATE OR REPLACE VIEW aie_enrichment_dashboard AS
SELECT 
  -- Overall progress
  COUNT(*) as total_employers,
  COUNT(CASE WHEN ch_fetch_status = 'completed' THEN 1 END) as enriched,
  COUNT(CASE WHEN ch_fetch_status = 'pending' THEN 1 END) as pending,
  COUNT(CASE WHEN ch_fetch_status = 'not_found' THEN 1 END) as not_found,
  COUNT(CASE WHEN ch_fetch_status = 'low_confidence' THEN 1 END) as low_confidence,
  COUNT(CASE WHEN ch_fetch_status = 'skipped_individual' THEN 1 END) as individuals,
  COUNT(CASE WHEN ch_fetch_status = 'error' THEN 1 END) as errors,
  -- Sector distribution (enriched only)
  COUNT(CASE WHEN acei_sector = 'Financial Services' THEN 1 END) as sector_financial,
  COUNT(CASE WHEN acei_sector = 'Professional Services' THEN 1 END) as sector_professional,
  COUNT(CASE WHEN acei_sector = 'Healthcare' THEN 1 END) as sector_healthcare,
  COUNT(CASE WHEN acei_sector = 'Technology' THEN 1 END) as sector_technology,
  COUNT(CASE WHEN acei_sector = 'Retail & Hospitality' THEN 1 END) as sector_retail,
  COUNT(CASE WHEN acei_sector = 'Manufacturing' THEN 1 END) as sector_manufacturing,
  COUNT(CASE WHEN acei_sector = 'Construction' THEN 1 END) as sector_construction,
  COUNT(CASE WHEN acei_sector = 'Education' THEN 1 END) as sector_education,
  COUNT(CASE WHEN acei_sector = 'Public Sector' THEN 1 END) as sector_public,
  COUNT(CASE WHEN acei_sector = 'Transport & Logistics' THEN 1 END) as sector_transport,
  -- Jurisdiction distribution (enriched only)
  COUNT(CASE WHEN jurisdiction_region = 'London' THEN 1 END) as jurisdiction_london,
  COUNT(CASE WHEN jurisdiction_region = 'Scotland' THEN 1 END) as jurisdiction_scotland,
  COUNT(CASE WHEN jurisdiction_region = 'Wales' THEN 1 END) as jurisdiction_wales,
  COUNT(CASE WHEN jurisdiction_region = 'Northern Ireland' THEN 1 END) as jurisdiction_ni,
  -- Size distribution (enriched only)
  COUNT(CASE WHEN headcount_band = 'micro_1_9' THEN 1 END) as size_micro,
  COUNT(CASE WHEN headcount_band = 'small_10_49' THEN 1 END) as size_small,
  COUNT(CASE WHEN headcount_band = 'medium_50_249' THEN 1 END) as size_medium,
  COUNT(CASE WHEN headcount_band = 'large_250_499' THEN 1 END) as size_large,
  COUNT(CASE WHEN headcount_band = 'enterprise_500_plus' THEN 1 END) as size_enterprise
FROM employer_master;

COMMENT ON FUNCTION get_pending_employers_by_priority IS 'AIE v1.0 - Returns pending employers ordered by match probability and commercial value';
COMMENT ON FUNCTION get_enrichment_stats IS 'AIE v1.0 - Returns enrichment progress by status';
COMMENT ON VIEW aie_enrichment_dashboard IS 'AIE v1.0 - Real-time enrichment progress dashboard';

