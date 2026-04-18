-- Migration: 20260228004730_multi_source_scoring_engine
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: multi_source_scoring_engine


-- ============================================================
-- ACEI MULTI-SOURCE SCORING ENGINE v1.1
-- Constitutional Authority: Art III §3.2.1
-- L_raw = (0.4 × EVI) + (0.3 × EII) + (0.3 × SCI)
-- ============================================================

-- 1. EVI computation: tribunal decisions vs baseline per category
CREATE OR REPLACE FUNCTION compute_evi(
  p_category TEXT,
  p_week_start DATE
) RETURNS TABLE(score INTEGER, decisions_count BIGINT, baseline INTEGER, ratio NUMERIC) AS $$
DECLARE
  v_baseline INTEGER;
  v_count BIGINT;
  v_ratio NUMERIC;
  v_score INTEGER;
BEGIN
  -- Annex A1 baselines per category
  v_baseline := CASE p_category
    WHEN 'unfair_dismissal' THEN 25
    WHEN 'discrimination_harassment' THEN 20
    WHEN 'wages_working_time' THEN 15
    WHEN 'whistleblowing' THEN 3
    WHEN 'employment_status' THEN 5
    WHEN 'redundancy_org_change' THEN 10
    WHEN 'parental_family_rights' THEN 10
    WHEN 'trade_union_collective' THEN 4
    WHEN 'breach_of_contract' THEN 8
    WHEN 'health_safety' THEN 3
    WHEN 'data_protection_privacy' THEN 2
    WHEN 'business_transfers_insolvency' THEN 5
    ELSE 5
  END;

  -- Count decisions in the scoring week
  SELECT COUNT(*) INTO v_count
  FROM tribunal_decisions
  WHERE acei_category = p_category
    AND decision_date >= p_week_start
    AND decision_date < p_week_start + INTERVAL '7 days';

  -- Ratio to baseline
  v_ratio := CASE WHEN v_baseline > 0 THEN v_count::NUMERIC / v_baseline ELSE 0 END;

  -- Score 1-5 per Annex A1 ratio thresholds
  v_score := CASE
    WHEN v_ratio <= 1.10 THEN 1
    WHEN v_ratio <= 1.25 THEN 2
    WHEN v_ratio <= 1.50 THEN 3
    WHEN v_ratio <= 2.00 THEN 4
    ELSE 5
  END;

  RETURN QUERY SELECT v_score, v_count, v_baseline, v_ratio;
END;
$$ LANGUAGE plpgsql STABLE;

-- 2. EII computation: enforcement intensity per category
CREATE OR REPLACE FUNCTION compute_eii(
  p_category TEXT,
  p_week_start DATE
) RETURNS TABLE(score INTEGER, events_count BIGINT, detail JSONB) AS $$
DECLARE
  v_count BIGINT;
  v_score INTEGER;
  v_recent_count BIGINT;
  v_detail JSONB;
BEGIN
  -- Count enforcement events in last 90 days for the relevant category
  SELECT COUNT(*) INTO v_count
  FROM enforcement_events_unified
  WHERE acei_category = p_category
    AND date_issued >= p_week_start - INTERVAL '90 days'
    AND date_issued <= p_week_start + INTERVAL '7 days';

  -- Count events in last 30 days (recent intensity signal)
  SELECT COUNT(*) INTO v_recent_count
  FROM enforcement_events_unified
  WHERE acei_category = p_category
    AND date_issued >= p_week_start - INTERVAL '30 days'
    AND date_issued <= p_week_start + INTERVAL '7 days';

  -- Score 1-5 based on enforcement density
  -- Thresholds calibrated for UK regulator output volumes
  v_score := CASE
    WHEN v_count = 0 THEN 1                          -- No enforcement activity
    WHEN v_count <= 2 AND v_recent_count = 0 THEN 1  -- Historical only, no recent
    WHEN v_count <= 5 THEN 2                          -- Low enforcement
    WHEN v_count <= 15 THEN 3                         -- Moderate enforcement
    WHEN v_count <= 30 THEN 4                         -- Elevated enforcement
    ELSE 5                                             -- High enforcement intensity
  END;

  v_detail := jsonb_build_object(
    '90d_count', v_count,
    '30d_count', v_recent_count
  );

  RETURN QUERY SELECT v_score, v_count, v_detail;
END;
$$ LANGUAGE plpgsql STABLE;

-- 3. SCI computation: structural change from legislation
CREATE OR REPLACE FUNCTION compute_sci(
  p_category TEXT,
  p_week_start DATE
) RETURNS TABLE(score INTEGER, leg_count BIGINT, detail JSONB) AS $$
DECLARE
  v_count BIGINT;
  v_max_impact INTEGER;
  v_recent_count BIGINT;
  v_score INTEGER;
  v_detail JSONB;
BEGIN
  -- Count employment legislation affecting this category in last 12 months
  SELECT COUNT(*), COALESCE(MAX(sci_impact_level), 0)
  INTO v_count, v_max_impact
  FROM legislative_changes
  WHERE employment_related = true
    AND date_published >= p_week_start - INTERVAL '12 months'
    AND date_published <= p_week_start + INTERVAL '7 days'
    AND (acei_categories @> ARRAY[p_category] OR acei_categories IS NULL);

  -- Count recent legislation (last 90 days) — structural momentum
  SELECT COUNT(*) INTO v_recent_count
  FROM legislative_changes
  WHERE employment_related = true
    AND date_published >= p_week_start - INTERVAL '90 days'
    AND date_published <= p_week_start + INTERVAL '7 days'
    AND (acei_categories @> ARRAY[p_category] OR acei_categories IS NULL);

  -- Score 1-5 based on legislative activity density and impact
  v_score := CASE
    WHEN v_count = 0 THEN 1                                      -- No legislative change
    WHEN v_count <= 3 AND v_max_impact <= 2 THEN 1               -- Minor SIs only
    WHEN v_count <= 5 OR v_max_impact = 3 THEN 2                 -- Moderate activity
    WHEN v_count <= 10 OR v_max_impact = 4 THEN 3                -- Significant activity
    WHEN v_count <= 20 OR v_max_impact = 5 THEN 4                -- Major structural change
    ELSE 5                                                         -- Exceptional legislative volume
  END;

  -- Boost if high-impact Act of Parliament specifically targets this category
  IF v_max_impact >= 4 AND v_recent_count >= 2 THEN
    v_score := LEAST(5, v_score + 1);
  END IF;

  v_detail := jsonb_build_object(
    '12m_count', v_count,
    '90d_count', v_recent_count,
    'max_impact', v_max_impact
  );

  RETURN QUERY SELECT v_score, v_count, v_detail;
END;
$$ LANGUAGE plpgsql STABLE;

-- 4. MASTER RECOMPUTATION FUNCTION
CREATE OR REPLACE FUNCTION recompute_acei_scores(
  p_week_start DATE DEFAULT CURRENT_DATE - ((EXTRACT(DOW FROM CURRENT_DATE)::INTEGER + 6) % 7),
  p_org_id UUID DEFAULT '00000000-0000-0000-0000-000000000000'::UUID
) RETURNS TABLE(category TEXT, l INTEGER, evi INTEGER, eii INTEGER, sci INTEGER, i INTEGER, crs INTEGER, wcs NUMERIC) AS $$
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
  v_dmr NUMERIC := 300;  -- Art II §2.9
  v_version TEXT := 'v1.1.0';

  -- Categories array
  v_categories TEXT[] := ARRAY[
    'unfair_dismissal','discrimination_harassment','wages_working_time',
    'whistleblowing','employment_status','redundancy_org_change',
    'parental_family_rights','trade_union_collective','breach_of_contract',
    'health_safety','data_protection_privacy','business_transfers_insolvency'
  ];
BEGIN
  -- Delete existing scores for this week (recomputation)
  DELETE FROM acei_category_scores WHERE week_start_date = p_week_start AND org_id = p_org_id;
  DELETE FROM acei_domain_scores WHERE week_start_date = p_week_start AND org_id = p_org_id;

  FOREACH v_category IN ARRAY v_categories LOOP
    -- Step 1: Compute EVI
    SELECT * INTO v_evi FROM compute_evi(v_category, p_week_start);

    -- Step 2: Compute EII
    SELECT * INTO v_eii FROM compute_eii(v_category, p_week_start);

    -- Step 3: Compute SCI
    SELECT * INTO v_sci FROM compute_sci(v_category, p_week_start);

    -- Step 4: L_raw = 0.4 × EVI + 0.3 × EII + 0.3 × SCI (Art III §3.2.1)
    v_l_raw := (0.4 * v_evi.score) + (0.3 * v_eii.score) + (0.3 * v_sci.score);
    v_l := GREATEST(1, LEAST(5, ROUND(v_l_raw)::INTEGER));  -- L ∈ {1,2,3,4,5}

    -- Step 4a: Week-over-week velocity cap (Art III §3.2.4)
    SELECT l INTO v_prev_l FROM acei_category_scores
    WHERE category = v_category AND org_id = p_org_id
      AND week_start_date = p_week_start - INTERVAL '7 days';
    IF v_prev_l IS NOT NULL AND v_l > v_prev_l + 1 AND v_sci.score < 4 THEN
      v_l := v_prev_l + 1;  -- Cap increase to +1 unless SCI ≥ 4
    END IF;

    -- Step 5: Impact (carried from existing scores or default)
    SELECT i INTO v_i FROM acei_category_scores
    WHERE category = v_category AND org_id = p_org_id
    ORDER BY week_start_date DESC LIMIT 1;
    IF v_i IS NULL THEN
      v_i := CASE v_category
        WHEN 'unfair_dismissal' THEN 3
        WHEN 'discrimination_harassment' THEN 5
        WHEN 'wages_working_time' THEN 3
        WHEN 'whistleblowing' THEN 5
        WHEN 'employment_status' THEN 3
        WHEN 'redundancy_org_change' THEN 4
        WHEN 'parental_family_rights' THEN 3
        WHEN 'trade_union_collective' THEN 3
        WHEN 'breach_of_contract' THEN 3
        WHEN 'health_safety' THEN 4
        WHEN 'data_protection_privacy' THEN 4
        WHEN 'business_transfers_insolvency' THEN 4
        ELSE 3
      END;
    END IF;

    -- Step 6: CRS = L × I (Art III §3.4.1)
    v_crs := v_l * v_i;

    -- Step 7: Multipliers (default SM=1.0, JM=1.0 for domain-level)
    v_sm := 1.0;
    v_jm := 1.0;
    v_wcs_pre := v_crs * v_sm * v_jm;
    v_wcs := v_wcs_pre;  -- No velocity applied yet (Art III §3.6.5)

    -- Accumulate DRT
    v_drt := v_drt + v_wcs;

    -- Insert category score
    INSERT INTO acei_category_scores (
      id, org_id, week_start_date, domain, category, version,
      l, i, sm, jm, v_category, v_domain, crs, wcs_pre, wcs, source_refs, created_at
    ) VALUES (
      gen_random_uuid(), p_org_id, p_week_start, 'employment', v_category, v_version,
      v_l, v_i, v_sm, v_jm, 0, 0, v_crs, v_wcs_pre, v_wcs,
      jsonb_build_object(
        'evi', v_evi.score, 'eii', v_eii.score, 'sci', v_sci.score,
        'l_raw', ROUND(v_l_raw, 2),
        'decisions_count', v_evi.decisions_count,
        'baseline', v_evi.baseline,
        'ratio', ROUND(v_evi.ratio, 3),
        'enforcement_events', v_eii.events_count,
        'enforcement_detail', v_eii.detail,
        'legislative_count', v_sci.leg_count,
        'legislative_detail', v_sci.detail
      ),
      NOW()
    );

    -- Return row
    category := v_category;
    l := v_l;
    evi := v_evi.score;
    eii := v_eii.score;
    sci := v_sci.score;
    i := v_i;
    crs := v_crs;
    wcs := v_wcs;
    RETURN NEXT;
  END LOOP;

  -- Compute Domain Index
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
