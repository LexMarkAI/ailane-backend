-- AILANE-CC-BRIEF-EILEEN-NEXUS-002-PART-A §2.1
-- Materialised views for Nexus live data visualisation.
-- Authority: AILANE-SPEC-EILEEN-UNIFIED-001 Art. 13.1, Art. 17.
-- Chairman ruling 2026-04-18 (CIE-PAR-A-GATE-0): Option A.
--   ACEI source = public.tribunal_decisions (acei_category text, CHECK-constrained
--   to canonical 12 + 'unclassified'; acei_categories_all text[] for relationships).
--   Legacy mapping CASE expression dropped — CHECK constraint enforces canonical
--   vocabulary; CASE would mask future schema drift.
-- Resilient to empty upstream tables (COALESCE on every aggregate).
-- Dependencies: tribunal_decisions, kl_provisions.

-- ===========================================================================
-- 1. Categories MV — 12 canonical ACEI primary nodes.
--    claim_frequency: COUNT of decisions per ACEI key in last 36 months.
--    provision_count: COUNT(DISTINCT instrument_id) of in-force provisions per
--                     ACEI key from public.kl_provisions.
-- ===========================================================================

CREATE MATERIALIZED VIEW public.vw_eileen_nexus_intel_categories AS
WITH
  canonical AS (
    SELECT unnest(ARRAY[
      'discrimination_harassment','whistleblowing','unfair_dismissal',
      'wages_working_time','redundancy_org_change','employment_status',
      'parental_family_rights','trade_union_collective','breach_of_contract',
      'health_safety','data_protection_privacy','business_transfers_insolvency'
    ]) AS acei_key
  ),
  tribunal_counts AS (
    SELECT
      acei_category AS acei_key,
      count(*)::int AS claim_count
    FROM public.tribunal_decisions
    WHERE acei_category IN (
      'discrimination_harassment','whistleblowing','unfair_dismissal',
      'wages_working_time','redundancy_org_change','employment_status',
      'parental_family_rights','trade_union_collective','breach_of_contract',
      'health_safety','data_protection_privacy','business_transfers_insolvency'
    )
    AND decision_date >= (CURRENT_DATE - INTERVAL '36 months')
    GROUP BY acei_category
  ),
  provision_counts AS (
    SELECT
      acei_category AS acei_key,
      count(DISTINCT instrument_id)::int AS provision_count
    FROM public.kl_provisions
    WHERE in_force = true
      AND acei_category IN (
        'discrimination_harassment','whistleblowing','unfair_dismissal',
        'wages_working_time','redundancy_org_change','employment_status',
        'parental_family_rights','trade_union_collective','breach_of_contract',
        'health_safety','data_protection_privacy','business_transfers_insolvency'
      )
    GROUP BY acei_category
  )
SELECT
  c.acei_key                              AS id,
  c.acei_key                              AS label,
  COALESCE(tc.claim_count, 0)             AS claim_frequency,
  COALESCE(pc.provision_count, 0)         AS provision_count,
  now()                                   AS snapshot_at
FROM canonical c
LEFT JOIN tribunal_counts  tc USING (acei_key)
LEFT JOIN provision_counts pc USING (acei_key);

CREATE UNIQUE INDEX uq_vw_eileen_nexus_intel_categories_id
  ON public.vw_eileen_nexus_intel_categories (id);

COMMENT ON MATERIALIZED VIEW public.vw_eileen_nexus_intel_categories IS
  'Nexus primary nodes — 12 canonical ACEI categories with last-36-month claim '
  'frequency from tribunal_decisions and in-force provision counts from '
  'kl_provisions. Refresh schedule: see §2.2 schedule_vw_eileen_nexus_intel_refresh.';

-- ===========================================================================
-- 2. Instruments MV — placeholder per Chairman ruling (CIE-PAR-A-GATE-0 item 2).
--    v3 §0.6 contract locks `instruments: []`. v4 brief will activate this MV
--    from kl_provisions. Empty schema-correct placeholder.
-- ===========================================================================

CREATE MATERIALIZED VIEW public.vw_eileen_nexus_intel_instruments AS
SELECT
  'placeholder'::text AS id,
  'placeholder'::text AS category_id,
  0::int              AS provision_count,
  now()               AS snapshot_at
WHERE false;

CREATE UNIQUE INDEX uq_vw_eileen_nexus_intel_instruments_id
  ON public.vw_eileen_nexus_intel_instruments (id);

COMMENT ON MATERIALIZED VIEW public.vw_eileen_nexus_intel_instruments IS
  'Nexus secondary nodes (statutory instruments). Held empty at v3 per §0.6 '
  'contract; activated by v4 brief from kl_provisions.';

-- ===========================================================================
-- 3. Relationships MV — pairwise ACEI co-occurrence within
--    tribunal_decisions.acei_categories_all (text[]).
--    Strength = number of decisions in which both keys co-occur.
-- ===========================================================================

CREATE MATERIALIZED VIEW public.vw_eileen_nexus_intel_relationships AS
WITH expanded AS (
  SELECT
    td.id AS decision_id,
    cat   AS acei_key
  FROM public.tribunal_decisions td,
       LATERAL unnest(td.acei_categories_all) AS cat
  WHERE td.acei_categories_all IS NOT NULL
    AND cat IN (
      'discrimination_harassment','whistleblowing','unfair_dismissal',
      'wages_working_time','redundancy_org_change','employment_status',
      'parental_family_rights','trade_union_collective','breach_of_contract',
      'health_safety','data_protection_privacy','business_transfers_insolvency'
    )
)
SELECT
  a.acei_key                               AS from_id,
  b.acei_key                               AS to_id,
  count(DISTINCT a.decision_id)::int       AS strength,
  now()                                    AS snapshot_at
FROM expanded a
JOIN expanded b
  ON  a.decision_id = b.decision_id
  AND a.acei_key    < b.acei_key
GROUP BY a.acei_key, b.acei_key;

CREATE UNIQUE INDEX uq_vw_eileen_nexus_intel_relationships_pair
  ON public.vw_eileen_nexus_intel_relationships (from_id, to_id);

COMMENT ON MATERIALIZED VIEW public.vw_eileen_nexus_intel_relationships IS
  'Nexus relationship edges — undirected co-occurrence of canonical ACEI keys '
  'within tribunal_decisions.acei_categories_all. Strength = number of decisions '
  'sharing the pair. Refresh schedule: see §2.2.';

-- ===========================================================================
-- 4. Umbrella view — composes the three MVs into the §0.6 contract shape.
--    Per-row snapshot_at columns are stripped — the umbrella emits a single
--    top-level snapshot_at and Part B's frontend only reads that.
-- ===========================================================================

CREATE VIEW public.vw_eileen_nexus_intel AS
SELECT
  ( SELECT jsonb_agg(to_jsonb(c) - 'snapshot_at' ORDER BY c.id)
      FROM public.vw_eileen_nexus_intel_categories c )       AS categories,
  ( SELECT COALESCE(jsonb_agg(to_jsonb(i) - 'snapshot_at'), '[]'::jsonb)
      FROM public.vw_eileen_nexus_intel_instruments i )      AS instruments,
  ( SELECT COALESCE(jsonb_agg(to_jsonb(r) - 'snapshot_at'), '[]'::jsonb)
      FROM public.vw_eileen_nexus_intel_relationships r )    AS relationships,
  now()                                                      AS snapshot_at;

COMMENT ON VIEW public.vw_eileen_nexus_intel IS
  'Umbrella view composing the three Nexus MVs into Art. 13.1 JSON shape. '
  'eileen-landing-intel v3 selects from this view. RLS is enforced by the '
  'underlying base tables; the Edge Function uses the service role.';
