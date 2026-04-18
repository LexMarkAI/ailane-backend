-- Migration: 20260413234221_create_get_surveillance_detail_rpc
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_get_surveillance_detail_rpc


CREATE OR REPLACE FUNCTION get_surveillance_detail()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    -- Recent parliamentary news (last 30 days, max 15 items)
    'recent_news', (
      SELECT coalesce(jsonb_agg(item), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'title', title,
          'source_type', source_type,
          'published_date', published_date::text,
          'summary', left(summary, 300),
          'url', url,
          'chamber', chamber,
          'acei_categories', acei_categories
        ) as item
        FROM parliamentary_intelligence
        WHERE published_date >= CURRENT_DATE - interval '30 days'
        ORDER BY published_date DESC, created_at DESC
        LIMIT 15
      ) sub
    ),
    
    -- Active legislative horizon entries (all auto-tracked, non-withdrawn)
    'tracked_legislation', (
      SELECT coalesce(jsonb_agg(item), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'title', legislation_title,
          'short_name', legislation_short_name,
          'type', legislation_type,
          'stage', parliament_stage,
          'status', status,
          'is_published', is_published,
          'headline', left(headline_summary, 300),
          'last_checked', last_status_check::text,
          'source_url', source_url,
          'affected_categories', affected_categories
        ) as item
        FROM kl_legislative_horizon
        WHERE auto_tracked = true
        AND status NOT IN ('withdrawn', 'defeated')
        ORDER BY 
          CASE WHEN status = 'enacted' THEN 1 
               WHEN parliament_stage = 'Royal Assent' THEN 2
               WHEN parliament_stage LIKE '%3rd reading%' THEN 3
               WHEN parliament_stage LIKE '%Report%' THEN 4
               WHEN parliament_stage LIKE '%Committee%' THEN 5
               WHEN parliament_stage LIKE '%2nd reading%' THEN 6
               ELSE 7 END,
          last_status_check DESC NULLS LAST
        LIMIT 25
      ) sub
    ),
    
    -- Recent surveillance alerts (last 30 days)
    'recent_alerts', (
      SELECT coalesce(jsonb_agg(item), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'title', title,
          'alert_class', alert_class,
          'alert_type', alert_type,
          'source', source,
          'detected_at', detected_at::text,
          'summary', left(summary, 300),
          'status', status,
          'source_url', source_url
        ) as item
        FROM kl_legislative_alerts
        WHERE detected_at >= now() - interval '30 days'
        ORDER BY detected_at DESC
        LIMIT 20
      ) sub
    ),
    
    -- Pipeline health snapshot (latest run per pipeline)
    'pipeline_health', (
      SELECT coalesce(jsonb_agg(item), '[]'::jsonb)
      FROM (
        SELECT DISTINCT ON (pipeline_code) jsonb_build_object(
          'pipeline_code', pipeline_code,
          'last_run', started_at::text,
          'status', status,
          'records_found', records_found,
          'records_new', records_new,
          'error', CASE WHEN status = 'failed' THEN left(error_message, 200) ELSE null END
        ) as item
        FROM pipeline_runs
        ORDER BY pipeline_code, started_at DESC
      ) sub
    ),
    
    -- Horizon SI watch entries (corrected column: is_active not active)
    'si_watch', (
      SELECT coalesce(jsonb_agg(item), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'act_title', act_title,
          'search_keywords', search_keywords,
          'last_si_found', last_si_found,
          'last_checked', last_checked_at::text
        ) as item
        FROM kl_horizon_si_watch
        WHERE is_active = true
      ) sub
    )
  ) INTO result;
  
  RETURN result;
END;
$$;

-- Grant execute to service_role only
REVOKE ALL ON FUNCTION get_surveillance_detail() FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION get_surveillance_detail() TO service_role;

