-- Migration: 20260228220136_acei_complete_scoring_engine
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: acei_complete_scoring_engine


-- ═══════════════════════════════════════════════════════════════
-- ACEI COMPLETE SCORING ENGINE
-- Constitutional Authority: Article III — Mathematical Engine
-- 
-- Implements the full computation sequence:
--   (a) Likelihood Derivation (EVI + EII + SCI → L)
--   (b) Impact Derivation (BFI + OM + RM → I)
--   (c) Category Raw Score (CRS = L × I)
--   (d) Multiplier Application (WCS_pre = CRS × SM × JM)
--   (e) Velocity Adjustment (WCS = WCS_pre × (1 + v_total))
--   (f) Aggregation (DRT = Σ WCS)
--   (g) Scaling (DI = min(100, (DRT/DMR) × 100))
--   (h) Mitigation Offset (AI = DI - MO)
-- ═══════════════════════════════════════════════════════════════

-- ┌─────────────────────────────────────────────────────────────┐
-- │ 1. EVI VIEW: Per-category tribunal volume scoring           │
-- │    Annex A2: Event Volume Index                             │
-- └─────────────────────────────────────────────────────────────┘
CREATE OR REPLACE VIEW v_evi_weekly AS
WITH weekly_counts AS (
  SELECT 
    date_trunc('week', decision_date)::date AS week_start,
    acei_category,
    COUNT(*) AS decisions_count
  FROM tribunal_decisions
  WHERE acei_category != 'unclassified'
    AND decision_date IS NOT NULL
  GROUP BY 1, 2
),
-- Empirical baselines: average weekly decisions per category over past 52 weeks
baselines AS (
  SELECT 
    acei_category,
    GREATEST(1, AVG(decisions_count))::numeric AS baseline_weekly
  FROM weekly_counts
  WHERE week_start >= (CURRENT_DATE - INTERVAL '52 weeks')
  GROUP BY acei_category
)
SELECT 
  w.week_start,
  w.acei_category,
  w.decisions_count,
  COALESCE(b.baseline_weekly, 5) AS baseline,
  ROUND(w.decisions_count / GREATEST(1, COALESCE(b.baseline_weekly, 5)), 2) AS volume_ratio,
  CASE
    WHEN w.decisions_count / GREATEST(1, COALESCE(b.baseline_weekly, 5)) <= 0.5 THEN 1
    WHEN w.decisions_count / GREATEST(1, COALESCE(b.baseline_weekly, 5)) <= 1.0 THEN 2
    WHEN w.decisions_count / GREATEST(1, COALESCE(b.baseline_weekly, 5)) <= 1.5 THEN 3
    WHEN w.decisions_count / GREATEST(1, COALESCE(b.baseline_weekly, 5)) <= 2.5 THEN 4
    ELSE 5
  END AS evi
FROM weekly_counts w
LEFT JOIN baselines b ON w.acei_category = b.acei_category;


-- ┌─────────────────────────────────────────────────────────────┐
-- │ 2. EII VIEW: Per-category enforcement intensity scoring     │
-- │    Annex A2: Enforcement Intensity Index                    │
-- │    Sources: EHRC, HSE, ICO enforcement actions              │
-- └─────────────────────────────────────────────────────────────┘
CREATE OR REPLACE VIEW v_eii_weekly AS
WITH enforcement_events AS (
  -- EHRC: maps to Cat 2 (Discrimination)
  SELECT date_issued, 'discrimination_harassment' AS acei_category,
         action_type, organisation_name
  FROM ehrc_enforcement_actions
  WHERE action_type = 'enforcement_action'
    AND description NOT LIKE '%travel advice%'
    AND description NOT LIKE '%small boat%'
    AND organisation_name NOT LIKE '%travel advice%'
  
  UNION ALL
  
  -- HSE: maps to Cat 10 (Health & Safety)
  SELECT date_issued, 'health_safety' AS acei_category,
         notice_type AS action_type, recipient_name AS organisation_name
  FROM hse_enforcement_notices
  
  UNION ALL
  
  -- ICO: maps to Cat 11 (Data Protection)
  SELECT date_issued, 'data_protection_privacy' AS acei_category,
         action_type, organisation_name
  FROM ico_enforcement_actions
),
-- Count enforcement events per category per 90-day window
enforcement_90d AS (
  SELECT 
    date_trunc('week', CURRENT_DATE)::date AS week_start,
    acei_category,
    COUNT(*) AS events_90d
  FROM enforcement_events
  WHERE date_issued >= (CURRENT_DATE - INTERVAL '90 days')
  GROUP BY acei_category
),
-- All 12 categories with default EII=1
all_categories AS (
  SELECT unnest(ARRAY[
    'unfair_dismissal', 'discrimination_harassment', 'wages_working_time',
    'whistleblowing', 'employment_status', 'redundancy_org_change',
    'parental_family_rights', 'trade_union_collective', 'breach_of_contract',
    'health_safety', 'data_protection_privacy', 'business_transfers_insolvency'
  ]) AS acei_category
)
SELECT 
  COALESCE(e.week_start, date_trunc('week', CURRENT_DATE)::date) AS week_start,
  c.acei_category,
  COALESCE(e.events_90d, 0) AS enforcement_events_90d,
  CASE
    WHEN COALESCE(e.events_90d, 0) = 0  THEN 1  -- Minimal
    WHEN COALESCE(e.events_90d, 0) <= 3  THEN 2  -- Routine
    WHEN COALESCE(e.events_90d, 0) <= 10 THEN 3  -- Elevated
    WHEN COALESCE(e.events_90d, 0) <= 25 THEN 4  -- Intensive
    ELSE 5                                         -- Maximum
  END AS eii
FROM all_categories c
LEFT JOIN enforcement_90d e ON c.acei_category = e.acei_category;


-- ┌─────────────────────────────────────────────────────────────┐
-- │ 3. SCI VIEW: Per-category structural change scoring         │
-- │    Annex A3: Structural Change Index                        │
-- │    Source: legislative_changes with acei_categories mapping  │
-- └─────────────────────────────────────────────────────────────┘
CREATE OR REPLACE VIEW v_sci_weekly AS
WITH category_legislation AS (
  SELECT 
    unnest(acei_categories) AS acei_category,
    sci_impact_level,
    date_enacted,
    title
  FROM legislative_changes
  WHERE acei_categories IS NOT NULL 
    AND array_length(acei_categories, 1) > 0
    AND date_enacted >= (CURRENT_DATE - INTERVAL '12 months')
),
-- Per-category: max impact level in past 12 months + recent activity count
category_sci AS (
  SELECT 
    acei_category,
    MAX(sci_impact_level) AS max_impact_12m,
    COUNT(*) AS changes_12m,
    COUNT(*) FILTER (WHERE date_enacted >= (CURRENT_DATE - INTERVAL '90 days')) AS changes_90d
  FROM category_legislation
  GROUP BY acei_category
),
all_categories AS (
  SELECT unnest(ARRAY[
    'unfair_dismissal', 'discrimination_harassment', 'wages_working_time',
    'whistleblowing', 'employment_status', 'redundancy_org_change',
    'parental_family_rights', 'trade_union_collective', 'breach_of_contract',
    'health_safety', 'data_protection_privacy', 'business_transfers_insolvency'
  ]) AS acei_category
)
SELECT 
  date_trunc('week', CURRENT_DATE)::date AS week_start,
  c.acei_category,
  COALESCE(s.changes_12m, 0) AS legislative_changes_12m,
  COALESCE(s.changes_90d, 0) AS legislative_changes_90d,
  COALESCE(s.max_impact_12m, 1) AS max_impact_level,
  -- SCI = max impact level found, or 1 if no changes
  LEAST(5, GREATEST(1, COALESCE(s.max_impact_12m, 1))) AS sci
FROM all_categories c
LEFT JOIN category_sci s ON c.acei_category = s.acei_category;


-- ┌─────────────────────────────────────────────────────────────┐
-- │ 4. IMPACT DEFAULTS: Per-category BFI from Annex A4/B       │
-- │    Until empirical compensation data flows from PDFs,       │
-- │    these are expert-assessed defaults per the Constitution  │
-- └─────────────────────────────────────────────────────────────┘
CREATE OR REPLACE VIEW v_impact_defaults AS
SELECT * FROM (VALUES
  -- (category, bfi, om, rm, impact_notes)
  ('unfair_dismissal',              3, 0, 0, 'Capped compensation. Median award ~£13k.'),
  ('discrimination_harassment',     5, 0, 0, 'UNCAPPED compensation. Injury to feelings. High reputational.'),
  ('wages_working_time',            3, 0, 0, 'Individual claims modest. Systemic class risk.'),
  ('whistleblowing',                5, 0, 0, 'UNCAPPED compensation. Catastrophic reputational.'),
  ('employment_status',             3, 0, 0, 'Tax/NI back-liability. IR35 HMRC exposure.'),
  ('redundancy_org_change',         4, 0, 0, 'Protective awards uncapped per employee. Collective risk.'),
  ('parental_family_rights',        3, 0, 0, 'Automatic unfair dismissal. Discrimination crossover.'),
  ('trade_union_collective',        3, 0, 0, 'Protective awards. Political dimension.'),
  ('breach_of_contract',            3, 0, 0, 'Capped at £25k in ET. High Court unlimited.'),
  ('health_safety',                 4, 0, 0, 'HSE prosecution risk. Corporate manslaughter exposure.'),
  ('data_protection_privacy',       4, 0, 0, 'ICO fines up to £17.5m. GDPR Article 82 claims.'),
  ('business_transfers_insolvency', 4, 0, 0, 'TUPE collective claims. NIF claims on insolvency.')
) AS t(acei_category, bfi, om, rm, notes);


-- ┌─────────────────────────────────────────────────────────────┐
-- │ 5. MULTIPLIER DEFAULTS: SM and JM                           │
-- │    Art 3.5: SM range 0.80-1.30, JM range 0.90-1.40         │
-- │    Default: SM=1.0, JM=1.0 (neutral, pre-calibration)      │
-- └─────────────────────────────────────────────────────────────┘
-- (SM and JM are client-specific. For the market-level index,
--  we use neutral defaults. These will be parameterised when
--  client scoring goes live.)


-- ┌─────────────────────────────────────────────────────────────┐
-- │ 6. MASTER SCORING FUNCTION                                  │
-- │    Art 3.1.2: Full computational sequence                   │
-- │    Deterministic. Identical inputs → identical outputs.      │
-- └─────────────────────────────────────────────────────────────┘
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
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_domain_velocity NUMERIC := 0;
  v_positive_cats INT := 0;
BEGIN
  -- ── Step 1: Compute sub-indices per category ──
  CREATE TEMP TABLE _cat_scores ON COMMIT DROP AS
  SELECT 
    evi.acei_category AS cat,
    -- (a) EVI
    COALESCE(evi.evi, 1) AS evi_s,
    -- (b) EII  
    COALESCE(eii.eii, 1) AS eii_s,
    -- (c) SCI
    COALESCE(sci.sci, 1) AS sci_s,
    -- (d) L_raw = (0.4 × EVI) + (0.3 × EII) + (0.3 × SCI)  [Art 3.2.1]
    ROUND((0.4 * COALESCE(evi.evi, 1) + 0.3 * COALESCE(eii.eii, 1) + 0.3 * COALESCE(sci.sci, 1))::numeric, 2) AS l_raw_c,
    -- (e) L = round(L_raw), bounded [1,5]  [Art 3.2.2-3]
    LEAST(5, GREATEST(1, ROUND(0.4 * COALESCE(evi.evi, 1) + 0.3 * COALESCE(eii.eii, 1) + 0.3 * COALESCE(sci.sci, 1)))) AS l_c,
    -- (f) Impact from defaults  [Art 3.3]
    LEAST(5, imp.bfi + imp.om + imp.rm) AS i_c,
    -- Source detail for audit trail
    jsonb_build_object(
      'evi', COALESCE(evi.evi, 1),
      'evi_decisions', COALESCE(evi.decisions_count, 0),
      'evi_baseline', COALESCE(evi.baseline, 0),
      'evi_ratio', COALESCE(evi.volume_ratio, 0),
      'eii', COALESCE(eii.eii, 1),
      'eii_enforcement_90d', COALESCE(eii.enforcement_events_90d, 0),
      'sci', COALESCE(sci.sci, 1),
      'sci_changes_12m', COALESCE(sci.legislative_changes_12m, 0),
      'sci_changes_90d', COALESCE(sci.legislative_changes_90d, 0),
      'sci_max_impact', COALESCE(sci.max_impact_level, 1),
      'bfi', imp.bfi,
      'om', imp.om,
      'rm', imp.rm
    ) AS src
  FROM v_eii_weekly eii
  LEFT JOIN v_evi_weekly evi 
    ON evi.acei_category = eii.acei_category AND evi.week_start = p_week_start
  LEFT JOIN v_sci_weekly sci 
    ON sci.acei_category = eii.acei_category
  LEFT JOIN v_impact_defaults imp 
    ON imp.acei_category = eii.acei_category;

  -- ── Step 2: Category velocity  [Art 3.6] ──
  -- Compare L to previous week
  -- (Simplified: velocity = 0 for first implementation, 
  --  enhanced when weekly history accumulates)
  
  -- ── Step 3: Domain velocity  [Annex C] ──
  -- v_domain = 0.05 if ≥4 categories show positive v_category ≥ 0.05
  -- Currently 0 until velocity tracking is active
  
  -- ── Return full scores ──
  RETURN QUERY
  SELECT 
    cs.cat,
    cs.evi_s,
    cs.eii_s,
    cs.sci_s,
    cs.l_raw_c,
    cs.l_c::int,
    cs.i_c::int,
    -- CRS = L × I  [Art 3.4.1]
    (cs.l_c * cs.i_c)::int AS crs_v,
    -- WCS_pre = CRS × SM × JM  [Art 3.5.1]
    ROUND((cs.l_c * cs.i_c * p_sm * p_jm)::numeric, 2) AS wcs_pre_v,
    -- Velocity (placeholder)
    0::numeric AS v_cat_v,
    0::numeric AS v_dom_v,
    0::numeric AS v_total_v,
    -- WCS = WCS_pre × (1 + v_total)
    ROUND((cs.l_c * cs.i_c * p_sm * p_jm * 1.0)::numeric, 2) AS wcs_v,
    cs.src
  FROM _cat_scores cs
  ORDER BY cs.cat;
END;
$$;


-- ┌─────────────────────────────────────────────────────────────┐
-- │ 7. WEEKLY SCORE WRITER                                      │
-- │    Calls compute_acei_scores, writes to both tables,        │
-- │    computes DRT and DI.                                     │
-- └─────────────────────────────────────────────────────────────┘
CREATE OR REPLACE FUNCTION write_acei_weekly_scores(
  p_week_start DATE DEFAULT date_trunc('week', CURRENT_DATE)::date,
  p_jurisdiction TEXT DEFAULT 'GB',
  p_version TEXT DEFAULT 'v1.0.0',
  p_dmr NUMERIC DEFAULT 300
)
RETURNS TABLE (
  domain_index INT,
  domain_raw_total NUMERIC,
  categories_scored INT
)
LANGUAGE plpgsql AS $$
DECLARE
  v_drt NUMERIC := 0;
  v_di INT := 0;
  v_count INT := 0;
  v_org_id UUID := '00000000-0000-0000-0000-000000000000'; -- Market-level
  r RECORD;
BEGIN
  -- Delete existing scores for this week (idempotent re-run)
  DELETE FROM acei_category_scores 
  WHERE week_start_date = p_week_start AND jurisdiction_code = p_jurisdiction;
  
  DELETE FROM acei_domain_scores 
  WHERE week_start_date = p_week_start AND jurisdiction_code = p_jurisdiction;

  -- Compute and write category scores
  FOR r IN SELECT * FROM compute_acei_scores(p_week_start, p_jurisdiction, p_version)
  LOOP
    INSERT INTO acei_category_scores (
      id, org_id, week_start_date, domain, category, version,
      evi, eii, sci, l_raw, l, i, 
      sm, jm, v_category, v_domain,
      crs, wcs_pre, wcs, source_refs,
      created_at, jurisdiction_code
    ) VALUES (
      gen_random_uuid(), v_org_id, p_week_start, 'employment', r.category, p_version,
      r.evi_score, r.eii_score, r.sci_score, r.l_raw_val, r.l_score, r.i_score,
      1.0, 1.0, r.v_cat, r.v_dom,
      r.crs_val, r.wcs_pre_val, r.wcs_val, r.source_detail,
      NOW(), p_jurisdiction
    );
    
    v_drt := v_drt + r.wcs_val;
    v_count := v_count + 1;
  END LOOP;

  -- DI = min(100, (DRT/DMR) × 100)  [Art 3.7.2]
  v_di := LEAST(100, ROUND((v_drt / p_dmr) * 100));

  -- Write domain score
  INSERT INTO acei_domain_scores (
    id, org_id, week_start_date, domain, version,
    drt, dmr, di, mo, ai,
    structural_flag, delta_weekly,
    created_at, jurisdiction_code
  ) VALUES (
    gen_random_uuid(), v_org_id, p_week_start, 'employment', p_version,
    ROUND(v_drt, 2), p_dmr, v_di, 0, v_di,
    false, 0,
    NOW(), p_jurisdiction
  );

  RETURN QUERY SELECT v_di, ROUND(v_drt, 2), v_count;
END;
$$;

-- Grant execute to service_role
GRANT EXECUTE ON FUNCTION compute_acei_scores TO service_role;
GRANT EXECUTE ON FUNCTION write_acei_weekly_scores TO service_role;

