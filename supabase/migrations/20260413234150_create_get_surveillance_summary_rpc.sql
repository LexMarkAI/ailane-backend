-- Migration: 20260413234150_create_get_surveillance_summary_rpc
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_get_surveillance_summary_rpc


CREATE OR REPLACE FUNCTION get_surveillance_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'tracked_bills_total', (
      SELECT count(*) FROM kl_legislative_horizon WHERE auto_tracked = true
    ),
    'tracked_bills_published', (
      SELECT count(*) FROM kl_legislative_horizon WHERE auto_tracked = true AND is_published = true
    ),
    'latest_news_date', (
      SELECT max(published_date)::text FROM parliamentary_intelligence
    ),
    'latest_news_title', (
      SELECT title FROM parliamentary_intelligence ORDER BY published_date DESC, created_at DESC LIMIT 1
    ),
    'active_alerts_count', (
      SELECT count(*) FROM kl_legislative_alerts WHERE status = 'pending_assessment'
    ),
    'latest_alert_date', (
      SELECT max(detected_at)::text FROM kl_legislative_alerts
    ),
    'pipelines_running', (
      SELECT count(DISTINCT pipeline_code) FROM pipeline_runs 
      WHERE started_at > now() - interval '48 hours' AND status = 'success'
    ),
    'pipelines_failing', (
      SELECT count(DISTINCT pipeline_code) FROM pipeline_runs pr1
      WHERE started_at = (
        SELECT max(started_at) FROM pipeline_runs pr2 WHERE pr2.pipeline_code = pr1.pipeline_code
      )
      AND status = 'failed'
    ),
    'surveillance_last_run', (
      SELECT max(created_at)::text FROM kl_horizon_tracking_log
    ),
    'data_freshness_hours', (
      SELECT round(EXTRACT(EPOCH FROM (now() - max(created_at))) / 3600, 1)
      FROM kl_horizon_tracking_log
    )
  ) INTO result;
  
  RETURN result;
END;
$$;

-- Grant execute to service_role only (called server-side by Edge Function)
REVOKE ALL ON FUNCTION get_surveillance_summary() FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION get_surveillance_summary() TO service_role;

