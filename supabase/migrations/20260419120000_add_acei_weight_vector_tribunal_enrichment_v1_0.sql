-- Migration: 20260419120000_add_acei_weight_vector_tribunal_enrichment_v1_0
-- Name: add_acei_weight_vector_tribunal_enrichment_v1_0
--
-- Adds the acei_weight_vector jsonb column to public.tribunal_enrichment,
-- its four CHECK constraints (shape, sum, bounds, confidence), a GIN index,
-- and the read-side projection view v_tribunal_enrichment_acei_signature.
--
-- Governance:
--   AILANE-SPEC-EILEEN-009 v1.0 (Cornerstone, AMD-072)
--   ACEI Founding Constitution v1.0 Article II §2.11 — twelve ACEI categories
--   AILANE-CC-BRIEF-ENRICHMENT-ACEI-WEIGHTS-001 (scope pared by Director
--   rulings dated 2026-04-19; agent prompt and INSERT-pathway work is
--   deferred to AILANE-CC-BRIEF-ENRICHMENT-ACEI-WEIGHTS-002).
--
-- Backward compatibility:
--   acei_weight_vector is nullable. Existing rows satisfy every CHECK
--   trivially (IS NULL branch). No existing column is altered. No backfill
--   is executed in this migration.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Column
-- ----------------------------------------------------------------------------
ALTER TABLE public.tribunal_enrichment
  ADD COLUMN IF NOT EXISTS acei_weight_vector jsonb;

COMMENT ON COLUMN public.tribunal_enrichment.acei_weight_vector IS
  'Twelve-category ACEI weight vector with provenance. Keys c1..c12 each hold a numeric weight in [0,1] and together sum to 1.0 (±0.005). A provenance object (source, computed_at, confidence) is required whenever the vector is non-null. Reflects the ACEI-category composition estimated by the enrichment agent; it is intelligence, not legal advice. Governed by AILANE-SPEC-EILEEN-009 v1.0.';

-- ----------------------------------------------------------------------------
-- 2. CHECK: shape (12 keys c1..c12 present + provenance object with triplet)
-- ----------------------------------------------------------------------------
ALTER TABLE public.tribunal_enrichment
  ADD CONSTRAINT tribunal_enrichment_acei_weight_vector_shape_chk
  CHECK (
    acei_weight_vector IS NULL
    OR (
      jsonb_typeof(acei_weight_vector) = 'object'
      AND acei_weight_vector ? 'c1'  AND acei_weight_vector ? 'c2'
      AND acei_weight_vector ? 'c3'  AND acei_weight_vector ? 'c4'
      AND acei_weight_vector ? 'c5'  AND acei_weight_vector ? 'c6'
      AND acei_weight_vector ? 'c7'  AND acei_weight_vector ? 'c8'
      AND acei_weight_vector ? 'c9'  AND acei_weight_vector ? 'c10'
      AND acei_weight_vector ? 'c11' AND acei_weight_vector ? 'c12'
      AND acei_weight_vector ? 'provenance'
      AND jsonb_typeof(acei_weight_vector -> 'provenance') = 'object'
      AND acei_weight_vector -> 'provenance' ? 'source'
      AND acei_weight_vector -> 'provenance' ? 'computed_at'
      AND acei_weight_vector -> 'provenance' ? 'confidence'
    )
  );

-- ----------------------------------------------------------------------------
-- 3. CHECK: sum of c1..c12 within tolerance of 1.0
-- ----------------------------------------------------------------------------
ALTER TABLE public.tribunal_enrichment
  ADD CONSTRAINT tribunal_enrichment_acei_weight_sum_chk
  CHECK (
    acei_weight_vector IS NULL
    OR (
      ABS(
        COALESCE((acei_weight_vector ->> 'c1')::numeric,  0) +
        COALESCE((acei_weight_vector ->> 'c2')::numeric,  0) +
        COALESCE((acei_weight_vector ->> 'c3')::numeric,  0) +
        COALESCE((acei_weight_vector ->> 'c4')::numeric,  0) +
        COALESCE((acei_weight_vector ->> 'c5')::numeric,  0) +
        COALESCE((acei_weight_vector ->> 'c6')::numeric,  0) +
        COALESCE((acei_weight_vector ->> 'c7')::numeric,  0) +
        COALESCE((acei_weight_vector ->> 'c8')::numeric,  0) +
        COALESCE((acei_weight_vector ->> 'c9')::numeric,  0) +
        COALESCE((acei_weight_vector ->> 'c10')::numeric, 0) +
        COALESCE((acei_weight_vector ->> 'c11')::numeric, 0) +
        COALESCE((acei_weight_vector ->> 'c12')::numeric, 0)
        - 1.0
      ) <= 0.005
    )
  );

-- ----------------------------------------------------------------------------
-- 4. CHECK: individual weights bounded in [0, 1]
-- ----------------------------------------------------------------------------
ALTER TABLE public.tribunal_enrichment
  ADD CONSTRAINT tribunal_enrichment_acei_weight_bounds_chk
  CHECK (
    acei_weight_vector IS NULL
    OR (
      (acei_weight_vector ->> 'c1')::numeric  BETWEEN 0 AND 1 AND
      (acei_weight_vector ->> 'c2')::numeric  BETWEEN 0 AND 1 AND
      (acei_weight_vector ->> 'c3')::numeric  BETWEEN 0 AND 1 AND
      (acei_weight_vector ->> 'c4')::numeric  BETWEEN 0 AND 1 AND
      (acei_weight_vector ->> 'c5')::numeric  BETWEEN 0 AND 1 AND
      (acei_weight_vector ->> 'c6')::numeric  BETWEEN 0 AND 1 AND
      (acei_weight_vector ->> 'c7')::numeric  BETWEEN 0 AND 1 AND
      (acei_weight_vector ->> 'c8')::numeric  BETWEEN 0 AND 1 AND
      (acei_weight_vector ->> 'c9')::numeric  BETWEEN 0 AND 1 AND
      (acei_weight_vector ->> 'c10')::numeric BETWEEN 0 AND 1 AND
      (acei_weight_vector ->> 'c11')::numeric BETWEEN 0 AND 1 AND
      (acei_weight_vector ->> 'c12')::numeric BETWEEN 0 AND 1
    )
  );

-- ----------------------------------------------------------------------------
-- 5. CHECK: provenance.confidence bounded in [0, 1]
-- ----------------------------------------------------------------------------
ALTER TABLE public.tribunal_enrichment
  ADD CONSTRAINT tribunal_enrichment_acei_weight_confidence_chk
  CHECK (
    acei_weight_vector IS NULL
    OR (
      (acei_weight_vector -> 'provenance' ->> 'confidence')::numeric
        BETWEEN 0 AND 1
    )
  );

-- ----------------------------------------------------------------------------
-- 6. GIN index for projection performance
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS tribunal_enrichment_acei_weight_vector_gin_idx
  ON public.tribunal_enrichment USING gin (acei_weight_vector);

-- ----------------------------------------------------------------------------
-- 7. Read-side projection view
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_tribunal_enrichment_acei_signature AS
SELECT
  te.id,
  te.decision_id,
  td.case_number,
  te.acei_weight_vector,
  te.acei_weight_vector -> 'provenance' ->> 'source'                     AS weight_source,
  (te.acei_weight_vector -> 'provenance' ->> 'confidence')::numeric      AS weight_confidence,
  (te.acei_weight_vector -> 'provenance' ->> 'computed_at')::timestamptz AS weight_computed_at,
  te.acei_primary_category,
  te.acei_secondary_categories
FROM public.tribunal_enrichment te
LEFT JOIN public.tribunal_decisions td ON td.id = te.decision_id
WHERE te.acei_weight_vector IS NOT NULL;

COMMENT ON VIEW public.v_tribunal_enrichment_acei_signature IS
  'Projection convenience view for Layer 3 consumers. Governed by AILANE-SPEC-EILEEN-009 v1.0.';

-- ============================================================================
-- End of migration 20260419120000_add_acei_weight_vector_tribunal_enrichment_v1_0
-- ============================================================================
