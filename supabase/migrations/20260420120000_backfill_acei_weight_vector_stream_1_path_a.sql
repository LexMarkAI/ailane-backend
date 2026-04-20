-- ============================================================================
-- Stream 1 Path A — deterministic scalar-synthesis backfill of
-- acei_weight_vector on tribunal_enrichment rows that carry an
-- ACEI primary category. Director Ruling B-8 distribution.
--
-- FOLDED: this migration also applies the Stream 2 CHECK amendment
-- (permit enrichment_schema_version = 'v2.2_provenance'). The repo's
-- standalone Stream 2 migration file at 20260419120500 is tombstoned --
-- it documents intent but will never be applied, because this migration
-- performs its DDL first in the same transaction.
--
-- Governance: AMD-072 (EILEEN-009 Cornerstone), AILANE-AMD-REG-001,
--             Director Ruling B-8 (AILANE-CC-BRIEF-ENRICHMENT-ACEI-WEIGHTS-001)
-- Prerequisites: v1.0 migration 20260419120000 (acei_weight_vector column
--                + 4 CHECK constraints + signature view) must be applied.
-- Atomicity: fold DDL, CREATE FUNCTION, self-test DO block, UPDATE, and
-- diagnostics DO block are all within one apply_migration transaction.
-- Any CHECK violation or self-test failure rolls back the entire operation.
--
-- Output = intelligence, not legal advice.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- §3.0  Stream 2 fold: permit enrichment_schema_version = 'v2.2_provenance'.
-- ----------------------------------------------------------------------------
-- Idempotent DROP + ADD. Pre-state (Director-relayed 2026-04-20):
--   IN-list = ['pre-v2.1','pdf_parse_v1','manual_v1','v2.1','v2.2']
-- Post-state appends 'v2.2_provenance' as the Stream 1 Path A sentinel.
-- The companion repo file 20260419120500_amend_chk_enrichment_schema_version_v2_2_provenance.sql
-- becomes a tombstone after this migration lands (documents intent; never applied).

ALTER TABLE public.tribunal_enrichment
  DROP CONSTRAINT chk_enrichment_schema_version;

ALTER TABLE public.tribunal_enrichment
  ADD CONSTRAINT chk_enrichment_schema_version
  CHECK (enrichment_schema_version IN (
    'pre-v2.1',
    'pdf_parse_v1',
    'manual_v1',
    'v2.1',
    'v2.2',
    'v2.2_provenance'
  ));

-- ----------------------------------------------------------------------------
-- §3.1  Synthesis function — deterministic, STABLE (inherits CURRENT_TIMESTAMP).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.synthesise_acei_weight_vector(
  p_primary       integer,
  p_secondaries   integer[],
  p_source        text    DEFAULT 'backfill.scalar_synthesis.v1.0',
  p_confidence    numeric DEFAULT 0.5
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  n_sec           integer;
  n_res           integer;
  pri_w           numeric;
  sec_each        numeric;
  res_each        numeric;
  weights         numeric[] := ARRAY[0,0,0,0,0,0,0,0,0,0,0,0]::numeric[];
  sec_distinct    integer[];
  i               integer;
  non_primary_sum numeric;
BEGIN
  IF p_primary IS NULL OR p_primary < 1 OR p_primary > 12 THEN
    RAISE EXCEPTION 'synthesise_acei_weight_vector: primary category % out of range (1..12)', p_primary;
  END IF;

  sec_distinct := COALESCE(
    (SELECT array_agg(DISTINCT x ORDER BY x)
     FROM unnest(COALESCE(p_secondaries, ARRAY[]::integer[])) x
     WHERE x BETWEEN 1 AND 12
       AND x <> p_primary),
    ARRAY[]::integer[]
  );
  n_sec := COALESCE(array_length(sec_distinct, 1), 0);
  n_res := 11 - n_sec;

  IF n_sec = 0 THEN
    pri_w := 0.8000; sec_each := 0;                           res_each := ROUND(0.2000 / 11.0, 4);
  ELSIF n_sec = 1 THEN
    pri_w := 0.6000; sec_each := 0.2500;                      res_each := ROUND(0.1500 / 10.0, 4);
  ELSIF n_sec = 2 THEN
    pri_w := 0.5500; sec_each := ROUND(0.3500 / 2.0, 4);      res_each := ROUND(0.1000 / 9.0, 4);
  ELSIF n_sec = 3 THEN
    pri_w := 0.5500; sec_each := ROUND(0.3500 / 3.0, 4);      res_each := ROUND(0.1000 / 8.0, 4);
  ELSIF n_sec BETWEEN 4 AND 10 THEN
    pri_w := 0.5000; sec_each := ROUND(0.4500 / n_sec, 4);    res_each := ROUND(0.0500 / n_res, 4);
  ELSIF n_sec = 11 THEN
    pri_w := 0.5000; sec_each := ROUND(0.5000 / 11.0, 4);     res_each := 0;
  ELSE
    RAISE EXCEPTION 'synthesise_acei_weight_vector: unreachable n_sec=% (should be 0..11)', n_sec;
  END IF;

  FOR i IN 1..12 LOOP
    IF i = p_primary THEN
      weights[i] := 0;
    ELSIF i = ANY(sec_distinct) THEN
      weights[i] := sec_each;
    ELSE
      weights[i] := res_each;
    END IF;
  END LOOP;

  SELECT COALESCE(SUM(w), 0)
    INTO non_primary_sum
    FROM unnest(weights) WITH ORDINALITY AS t(w, ord)
    WHERE ord <> p_primary;

  weights[p_primary] := 1.0000 - non_primary_sum;

  RETURN jsonb_build_object(
    'c1',  weights[1],  'c2',  weights[2],  'c3',  weights[3],
    'c4',  weights[4],  'c5',  weights[5],  'c6',  weights[6],
    'c7',  weights[7],  'c8',  weights[8],  'c9',  weights[9],
    'c10', weights[10], 'c11', weights[11], 'c12', weights[12],
    'provenance', jsonb_build_object(
      'source',      p_source,
      'computed_at', to_char(CURRENT_TIMESTAMP AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'confidence',  p_confidence
    )
  );
END;
$function$;

COMMENT ON FUNCTION public.synthesise_acei_weight_vector(integer, integer[], text, numeric) IS
  'Deterministic ACEI weight vector synthesis. Path A scalar-synthesis backfill per Director Ruling B-8 (AILANE-CC-BRIEF-ENRICHMENT-ACEI-WEIGHTS-001). Marked STABLE because CURRENT_TIMESTAMP is STABLE within a transaction; outputs intelligence, not legal advice. Governed by AILANE-SPEC-EILEEN-009 v1.0 (Cornerstone, AMD-072).';

-- ----------------------------------------------------------------------------
-- §2.3  Pre-backfill self-test — seven inline replicated assertion blocks.
--        Flattened form (no nested PROCEDURE, no ragged array literal).
--        Any failed assertion raises and rolls back the whole migration
--        before the UPDATE runs.
-- ----------------------------------------------------------------------------
DO $test$
DECLARE
  v     jsonb;
  total numeric;
BEGIN
  -- Assertion 1: N=0 (primary=1, no secondaries)
  v := public.synthesise_acei_weight_vector(1, ARRAY[]::integer[]);
  SELECT (v->>'c1')::numeric + (v->>'c2')::numeric + (v->>'c3')::numeric
       + (v->>'c4')::numeric + (v->>'c5')::numeric + (v->>'c6')::numeric
       + (v->>'c7')::numeric + (v->>'c8')::numeric + (v->>'c9')::numeric
       + (v->>'c10')::numeric + (v->>'c11')::numeric + (v->>'c12')::numeric
    INTO total;
  IF ABS(total - 1.0) > 0.005 THEN
    RAISE EXCEPTION 'Self-test FAILED [N=0]: primary=1 sec=[] sum=% (tolerance 0.005)', total;
  END IF;

  -- Assertion 2: N=1
  v := public.synthesise_acei_weight_vector(1, ARRAY[2]);
  SELECT (v->>'c1')::numeric + (v->>'c2')::numeric + (v->>'c3')::numeric
       + (v->>'c4')::numeric + (v->>'c5')::numeric + (v->>'c6')::numeric
       + (v->>'c7')::numeric + (v->>'c8')::numeric + (v->>'c9')::numeric
       + (v->>'c10')::numeric + (v->>'c11')::numeric + (v->>'c12')::numeric
    INTO total;
  IF ABS(total - 1.0) > 0.005 THEN
    RAISE EXCEPTION 'Self-test FAILED [N=1]: primary=1 sec=[2] sum=% (tolerance 0.005)', total;
  END IF;

  -- Assertion 3: N=2
  v := public.synthesise_acei_weight_vector(1, ARRAY[2, 3]);
  SELECT (v->>'c1')::numeric + (v->>'c2')::numeric + (v->>'c3')::numeric
       + (v->>'c4')::numeric + (v->>'c5')::numeric + (v->>'c6')::numeric
       + (v->>'c7')::numeric + (v->>'c8')::numeric + (v->>'c9')::numeric
       + (v->>'c10')::numeric + (v->>'c11')::numeric + (v->>'c12')::numeric
    INTO total;
  IF ABS(total - 1.0) > 0.005 THEN
    RAISE EXCEPTION 'Self-test FAILED [N=2]: primary=1 sec=[2,3] sum=% (tolerance 0.005)', total;
  END IF;

  -- Assertion 4: N=3
  v := public.synthesise_acei_weight_vector(1, ARRAY[2, 3, 4]);
  SELECT (v->>'c1')::numeric + (v->>'c2')::numeric + (v->>'c3')::numeric
       + (v->>'c4')::numeric + (v->>'c5')::numeric + (v->>'c6')::numeric
       + (v->>'c7')::numeric + (v->>'c8')::numeric + (v->>'c9')::numeric
       + (v->>'c10')::numeric + (v->>'c11')::numeric + (v->>'c12')::numeric
    INTO total;
  IF ABS(total - 1.0) > 0.005 THEN
    RAISE EXCEPTION 'Self-test FAILED [N=3]: primary=1 sec=[2,3,4] sum=% (tolerance 0.005)', total;
  END IF;

  -- Assertion 5: N=4
  v := public.synthesise_acei_weight_vector(1, ARRAY[2, 3, 4, 5]);
  SELECT (v->>'c1')::numeric + (v->>'c2')::numeric + (v->>'c3')::numeric
       + (v->>'c4')::numeric + (v->>'c5')::numeric + (v->>'c6')::numeric
       + (v->>'c7')::numeric + (v->>'c8')::numeric + (v->>'c9')::numeric
       + (v->>'c10')::numeric + (v->>'c11')::numeric + (v->>'c12')::numeric
    INTO total;
  IF ABS(total - 1.0) > 0.005 THEN
    RAISE EXCEPTION 'Self-test FAILED [N=4]: primary=1 sec=[2,3,4,5] sum=% (tolerance 0.005)', total;
  END IF;

  -- Assertion 6: N=5 (contract guard; not exercised by live data)
  v := public.synthesise_acei_weight_vector(1, ARRAY[2, 3, 4, 5, 6]);
  SELECT (v->>'c1')::numeric + (v->>'c2')::numeric + (v->>'c3')::numeric
       + (v->>'c4')::numeric + (v->>'c5')::numeric + (v->>'c6')::numeric
       + (v->>'c7')::numeric + (v->>'c8')::numeric + (v->>'c9')::numeric
       + (v->>'c10')::numeric + (v->>'c11')::numeric + (v->>'c12')::numeric
    INTO total;
  IF ABS(total - 1.0) > 0.005 THEN
    RAISE EXCEPTION 'Self-test FAILED [N=5]: primary=1 sec=[2,3,4,5,6] sum=% (tolerance 0.005)', total;
  END IF;

  -- Assertion 7: N=11 (contract guard; upper bound)
  v := public.synthesise_acei_weight_vector(1, ARRAY[2,3,4,5,6,7,8,9,10,11,12]);
  SELECT (v->>'c1')::numeric + (v->>'c2')::numeric + (v->>'c3')::numeric
       + (v->>'c4')::numeric + (v->>'c5')::numeric + (v->>'c6')::numeric
       + (v->>'c7')::numeric + (v->>'c8')::numeric + (v->>'c9')::numeric
       + (v->>'c10')::numeric + (v->>'c11')::numeric + (v->>'c12')::numeric
    INTO total;
  IF ABS(total - 1.0) > 0.005 THEN
    RAISE EXCEPTION 'Self-test FAILED [N=11]: primary=1 sec=[2..12] sum=% (tolerance 0.005)', total;
  END IF;

  RAISE NOTICE '[synthesise_acei_weight_vector] self-test PASSED for N=0,1,2,3,4,5,11';
END $test$;

-- ----------------------------------------------------------------------------
-- §3.2  Path A backfill — scalar synthesis on every eligible row.
--        Governed by AMD-072 / EILEEN-009. Director Ruling B-8 distribution.
-- ----------------------------------------------------------------------------

UPDATE public.tribunal_enrichment
SET
  acei_weight_vector        = public.synthesise_acei_weight_vector(
                                 acei_primary_category,
                                 acei_secondary_categories
                               ),
  enrichment_schema_version = 'v2.2_provenance'
WHERE acei_weight_vector IS NULL
  AND acei_primary_category IS NOT NULL
  AND acei_primary_category BETWEEN 1 AND 12;

-- ----------------------------------------------------------------------------
-- §3.2  Post-backfill diagnostics — raises on any remaining Path A eligibility.
-- ----------------------------------------------------------------------------
DO $backfill_report$
DECLARE
  total_rows         bigint;
  with_weight_vector bigint;
  path_a_remaining   bigint;
  path_b_remaining   bigint;
BEGIN
  SELECT COUNT(*) INTO total_rows FROM public.tribunal_enrichment;

  SELECT COUNT(*) INTO with_weight_vector
    FROM public.tribunal_enrichment
    WHERE acei_weight_vector IS NOT NULL;

  SELECT COUNT(*) INTO path_a_remaining
    FROM public.tribunal_enrichment
    WHERE acei_weight_vector IS NULL
      AND acei_primary_category IS NOT NULL
      AND acei_primary_category BETWEEN 1 AND 12;

  SELECT COUNT(*) INTO path_b_remaining
    FROM public.tribunal_enrichment
    WHERE acei_weight_vector IS NULL
      AND acei_primary_category IS NULL;

  RAISE NOTICE 'Stream 1 Path A backfill complete';
  RAISE NOTICE '  total rows:           %', total_rows;
  RAISE NOTICE '  with weight vector:   %', with_weight_vector;
  RAISE NOTICE '  path A remaining:     % (expected 0)', path_a_remaining;
  RAISE NOTICE '  path B deferred:      % (Stream 3 scope)', path_b_remaining;

  IF path_a_remaining <> 0 THEN
    RAISE EXCEPTION 'Stream 1 Path A backfill incomplete: % rows still eligible', path_a_remaining;
  END IF;
END $backfill_report$;

-- ============================================================================
-- End of migration 20260420120000_backfill_acei_weight_vector_stream_1_path_a
-- ============================================================================
