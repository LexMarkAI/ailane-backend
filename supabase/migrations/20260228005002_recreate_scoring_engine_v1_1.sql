-- Migration: 20260228005002_recreate_scoring_engine_v1_1
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: recreate_scoring_engine_v1_1


CREATE OR REPLACE FUNCTION recompute_acei_scores(
  p_week_start DATE DEFAULT CURRENT_DATE - ((EXTRACT(DOW FROM CURRENT_DATE)::INTEGER + 6) % 7),
  p_org_id UUID DEFAULT '00000000-0000-0000-0000-000000000000'::UUID
) RETURNS TABLE(out_category TEXT, out_l INTEGER, out_evi INTEGER, out_eii INTEGER, out_sci INTEGER, out_i INTEGER, out_crs INTEGER, out_wcs NUMERIC) AS $$
DECLARE
  v_category TEXT;
  v_evi RECORD;
  v_eii RECORD;
  v_sci RECORD;
  v_l_raw NUMERIC;
  v_l INTEGER;
  v_prev_l INTEGER;
  v_i INTEGER;
  v_crs INTEGER;
  v_sm NUMERIC;
  v_jm NUMERIC;
  v_wcs_pre NUMERIC;
  v_wcs NUMERIC;
  v_drt NUMERIC := 0;
  v_di INTEGER;
  v_dmr NUMERIC := 300;
  v_version TEXT := 'v1.1.0';
  v_categories TEXT[] := ARRAY[
    'unfair_dismissal','discrimination_harassment','wages_working_time',
    'whistleblowing','employment_status','redundancy_org_change',
    'parental_family_rights','trade_union_collective','breach_of_contract',
    'health_safety','data_protection_privacy','business_transfers_insolvency'
  ];
BEGIN
  DELETE FROM acei_category_scores WHERE week_start_date = p_week_start AND org_id = p_org_id;
  DELETE FROM acei_domain_scores WHERE week_start_date = p_week_start AND org_id = p_org_id;

  FOREACH v_category IN ARRAY v_categories LOOP
    SELECT * INTO v_evi FROM compute_evi(v_category, p_week_start);
    SELECT * INTO v_eii FROM compute_eii(v_category, p_week_start);
    SELECT * INTO v_sci FROM compute_sci(v_category, p_week_start);

    v_l_raw := (0.4 * v_evi.score) + (0.3 * v_eii.score) + (0.3 * v_sci.score);
    v_l := GREATEST(1, LEAST(5, ROUND(v_l_raw)::INTEGER));

    SELECT acs.l INTO v_prev_l FROM acei_category_scores acs
    WHERE acs.category = v_category AND acs.org_id = p_org_id
      AND acs.week_start_date = p_week_start - INTERVAL '7 days';
    IF v_prev_l IS NOT NULL AND v_l > v_prev_l + 1 AND v_sci.score < 4 THEN
      v_l := v_prev_l + 1;
    END IF;

    SELECT acs.i INTO v_i FROM acei_category_scores acs
    WHERE acs.category = v_category AND acs.org_id = p_org_id
      AND acs.week_start_date < p_week_start
    ORDER BY acs.week_start_date DESC LIMIT 1;
    IF v_i IS NULL THEN
      v_i := CASE v_category
        WHEN 'unfair_dismissal' THEN 3 WHEN 'discrimination_harassment' THEN 5
        WHEN 'wages_working_time' THEN 3 WHEN 'whistleblowing' THEN 5
        WHEN 'employment_status' THEN 3 WHEN 'redundancy_org_change' THEN 4
        WHEN 'parental_family_rights' THEN 3 WHEN 'trade_union_collective' THEN 3
        WHEN 'breach_of_contract' THEN 3 WHEN 'health_safety' THEN 4
        WHEN 'data_protection_privacy' THEN 4 WHEN 'business_transfers_insolvency' THEN 4
        ELSE 3
      END;
    END IF;

    v_crs := v_l * v_i;
    v_sm := 1.0; v_jm := 1.0;
    v_wcs_pre := v_crs * v_sm * v_jm;
    v_wcs := v_wcs_pre;
    v_drt := v_drt + v_wcs;

    INSERT INTO acei_category_scores (
      id, org_id, week_start_date, domain, category, version,
      l, i, sm, jm, v_category, v_domain, crs, wcs_pre, wcs, source_refs, created_at
    ) VALUES (
      gen_random_uuid(), p_org_id, p_week_start, 'employment', v_category, v_version,
      v_l, v_i, v_sm, v_jm, 0, 0, v_crs, v_wcs_pre, v_wcs,
      jsonb_build_object(
        'evi', v_evi.score, 'eii', v_eii.score, 'sci', v_sci.score,
        'l_raw', ROUND(v_l_raw, 2),
        'decisions_count', v_evi.decisions_count, 'baseline', v_evi.baseline,
        'ratio', ROUND(v_evi.ratio, 3),
        'enforcement_events', v_eii.events_count,
        'enforcement_detail', v_eii.detail,
        'legislative_count', v_sci.leg_count,
        'legislative_detail', v_sci.detail
      ), NOW()
    );

    out_category := v_category; out_l := v_l; out_evi := v_evi.score;
    out_eii := v_eii.score; out_sci := v_sci.score; out_i := v_i;
    out_crs := v_crs; out_wcs := v_wcs;
    RETURN NEXT;
  END LOOP;

  v_di := LEAST(100, ROUND((v_drt / v_dmr) * 100)::INTEGER);

  INSERT INTO acei_domain_scores (
    id, org_id, week_start_date, domain, version,
    drt, dmr, di, mo, ai, structural_flag, delta_weekly, created_at
  ) VALUES (
    gen_random_uuid(), p_org_id, p_week_start, 'employment', v_version,
    v_drt, v_dmr, v_di, 0, v_di, false, 0, NOW()
  );

  RETURN;
END;
$$ LANGUAGE plpgsql;
