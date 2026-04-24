-- ============================================================================
-- AILANE-SPEC-DMSP-002-W7 §12.4
-- AMD-089 Stage A · CC Build Brief 1 · §2.7
-- Migration: w7_add_sweep_check_constraint_not_valid
-- Purpose : Add CHECK constraint guaranteeing that any w7_sweep provenance
--           block emitting rro_value=TRUE carries a non-empty rro_signals
--           array (same for soa_value / soa_signals). Constraint is vacuous
--           where the w7_sweep block is absent, so rows not yet touched by
--           the sweep are unaffected.
--           NOT VALID posture INTENTIONAL: existing 34,205 rows carry no
--           w7_sweep block and must not be retroactively validated. VALIDATE
--           is the first migration of Stage B (§5.1), executed after sweep
--           completion when every row carries a w7_sweep block or is out
--           of scope.
-- Brief    : AILANE-CC-BRIEF-001 v1.1 (ratified CEO-RAT-AMD-089, 24 Apr 2026)
-- Scope    : Chairman §0.1 confirms constraint ABSENT prior to apply.
-- ============================================================================

ALTER TABLE public.tribunal_enrichment
ADD CONSTRAINT chk_w7_sweep_true_has_signals CHECK (
    -- Constraint is vacuous where the w7_sweep provenance block is absent,
    -- so rows not yet touched by the sweep are unaffected by this constraint.
    llm_raw_response -> 'w7_sweep' IS NULL
    OR (
        -- RRO limb: if rro_value is TRUE, rro_signals array must be non-empty.
        -- (IS DISTINCT FROM TRUE evaluates NULL and FALSE identically to 'not TRUE',
        --  so the limb passes for FALSE or NULL emissions without requiring signals.)
        (
            (llm_raw_response -> 'w7_sweep' ->> 'rro_value')::boolean
                IS DISTINCT FROM TRUE
            OR jsonb_array_length(
                   llm_raw_response -> 'w7_sweep' -> 'rro_signals'
               ) > 0
        )
        AND
        -- SOA limb: if soa_value is TRUE, soa_signals array must be non-empty.
        (
            (llm_raw_response -> 'w7_sweep' ->> 'soa_value')::boolean
                IS DISTINCT FROM TRUE
            OR jsonb_array_length(
                   llm_raw_response -> 'w7_sweep' -> 'soa_signals'
               ) > 0
        )
    )
) NOT VALID;
