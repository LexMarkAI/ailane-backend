-- Migration: 20260228220200_fix_acei_scoring_function
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_acei_scoring_function


-- Fix: rewrite without temp tables, use CTEs instead
CREATE OR REPLACE FUNCTION compute_acei_scores(
  p_week_start DATE DEFAULT date_trunc('week', CURRENT_DATE)::date,
  p_jurisdiction TEXT DEFAULT 'GB',
  p_version TEXT DEFAULT 'v1.0.0',
  p_sm NUMERIC DEFAULT 1.0,
  p_jm NUMERIC DEFAULT 1.0,
  p_dmr NUMERIC DEFAULT 300
)
RETURNS TABLE (
  category TEXT,
  evi_score INT,
  eii_score INT, 
  sci_score INT,
  l_raw_val NUMERIC,
  l_score INT,
  i_score INT,
  crs_val INT,
  wcs_pre_val NUMERIC,
  v_cat NUMERIC,
  v_dom NUMERIC,
  v_total_val NUMERIC,
  wcs_val NUMERIC,
  source_detail JSONB
)
LANGUAGE sql STABLE AS $$
  WITH cat_scores AS (
    SELECT 
      eii.acei_category AS cat,
      COALESCE(evi.evi, 1) AS evi_s,
      COALESCE(eii.eii, 1) AS eii_s,
      COALESCE(sci.sci, 1) AS sci_s,
      -- L_raw = (0.4 × EVI) + (0.3 × EII) + (0.3 × SCI)
      ROUND((0.4 * COALESCE(evi.evi, 1) + 0.3 * COALESCE(eii.eii, 1) + 0.3 * COALESCE(sci.sci, 1))::numeric, 2) AS l_raw_c,
      LEAST(5, GREATEST(1, ROUND(0.4 * COALESCE(evi.evi, 1) + 0.3 * COALESCE(eii.eii, 1) + 0.3 * COALESCE(sci.sci, 1)))) AS l_c,
      LEAST(5, imp.bfi + imp.om + imp.rm) AS i_c,
      jsonb_build_object(
        'evi', COALESCE(evi.evi, 1),
        'evi_decisions', COALESCE(evi.decisions_count, 0),
        'evi_baseline', ROUND(COALESCE(evi.baseline, 0)::numeric, 1),
        'evi_ratio', COALESCE(evi.volume_ratio, 0),
        'eii', COALESCE(eii.eii, 1),
        'eii_enforcement_90d', COALESCE(eii.enforcement_events_90d, 0),
        'sci', COALESCE(sci.sci, 1),
        'sci_changes_12m', COALESCE(sci.legislative_changes_12m, 0),
        'sci_changes_90d', COALESCE(sci.legislative_changes_90d, 0),
        'sci_max_impact', COALESCE(sci.max_impact_level, 1),
        'bfi', imp.bfi, 'om', imp.om, 'rm', imp.rm
      ) AS src
    FROM v_eii_weekly eii
    LEFT JOIN v_evi_weekly evi 
      ON evi.acei_category = eii.acei_category AND evi.week_start = p_week_start
    LEFT JOIN v_sci_weekly sci 
      ON sci.acei_category = eii.acei_category
    LEFT JOIN v_impact_defaults imp 
      ON imp.acei_category = eii.acei_category
  )
  SELECT 
    cs.cat,
    cs.evi_s,
    cs.eii_s,
    cs.sci_s,
    cs.l_raw_c,
    cs.l_c::int,
    cs.i_c::int,
    (cs.l_c * cs.i_c)::int,
    ROUND((cs.l_c * cs.i_c * p_sm * p_jm)::numeric, 2),
    0::numeric,  -- v_category placeholder
    0::numeric,  -- v_domain placeholder
    0::numeric,  -- v_total placeholder
    ROUND((cs.l_c * cs.i_c * p_sm * p_jm)::numeric, 2),
    cs.src
  FROM cat_scores cs
  ORDER BY cs.cat;
$$;

