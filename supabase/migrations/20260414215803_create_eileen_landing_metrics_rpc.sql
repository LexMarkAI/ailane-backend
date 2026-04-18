-- Migration: 20260414215803_create_eileen_landing_metrics_rpc
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_eileen_landing_metrics_rpc


CREATE OR REPLACE FUNCTION eileen_landing_metrics()
RETURNS TABLE (
  total_decisions bigint,
  total_enriched bigint,
  total_employers bigint,
  distinct_judges bigint,
  total_awards_mapped numeric,
  cases_with_awards bigint,
  median_award numeric,
  latest_scrape_date date,
  latest_decision_date date,
  kl_provisions bigint,
  kl_cases bigint,
  hse_notices bigint,
  hse_prosecutions bigint,
  coroner_reports bigint,
  ehrc_actions bigint,
  legislative_changes bigint
) LANGUAGE sql STABLE AS $$
  SELECT
    (SELECT COUNT(*) FROM tribunal_decisions),
    (SELECT COUNT(*) FROM tribunal_enrichment),
    (SELECT COUNT(*) FROM employer_master),
    (SELECT COUNT(DISTINCT judge_name) FROM tribunal_enrichment),
    (SELECT COALESCE(SUM(CASE WHEN award_total > 0 THEN award_total ELSE 0 END), 0) FROM tribunal_enrichment),
    (SELECT COUNT(*) FROM tribunal_enrichment WHERE award_total > 0),
    (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY award_total) FROM tribunal_enrichment WHERE award_total > 0),
    (SELECT MAX(scraped_at)::date FROM tribunal_decisions),
    (SELECT MAX(decision_date) FROM tribunal_decisions),
    (SELECT COUNT(*) FROM kl_provisions),
    (SELECT COUNT(*) FROM kl_cases),
    (SELECT COUNT(*) FROM hse_enforcement_notices),
    (SELECT COUNT(*) FROM hse_prosecutions),
    (SELECT COUNT(*) FROM coroner_pfd_reports),
    (SELECT COUNT(*) FROM ehrc_enforcement_actions),
    (SELECT COUNT(*) FROM legislative_changes);
$$;

