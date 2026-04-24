-- ============================================================================
-- AILANE-SPEC-DMSP-002-W7 §12.4
-- AMD-089 Stage A · CC Build Brief 1 EXEC-01 · §4
-- Migration: w7_add_sweep_check_constraint_not_valid
-- Purpose : Add CHECK constraint guaranteeing that any w7_sweep provenance
--           block emitting rro_value=TRUE carries a non-empty rro_signals
--           array (same for soa_value / soa_signals). Constraint is vacuous
--           where w7_sweep_provenance is NULL, so rows not yet touched by
--           the sweep are unaffected.
--           NOT VALID posture INTENTIONAL: existing 34,205 rows (pre-sweep)
--           all have w7_sweep_provenance = NULL and must not be retroactively
--           validated. VALIDATE is the first migration of Stage B (§5.1),
--           executed after sweep completion when every row carries a
--           provenance block or is out of scope.
-- Brief    : AILANE-CC-BRIEF-001-EXEC-01 (Director-ratified 24 Apr 2026)
-- EXEC-01  : Targets dedicated w7_sweep_provenance jsonb column (§2) instead
--           of llm_raw_response -> 'w7_sweep'. Predicate semantics preserved
--           byte-for-byte. Three-valued logic unchanged.
-- Depends  : §2 EXEC-01 (w7_sweep_provenance column) must be applied first.
-- ============================================================================

ALTER TABLE public.tribunal_enrichment
ADD CONSTRAINT chk_w7_sweep_true_has_signals CHECK (
    -- Constraint is vacuous where w7_sweep_provenance is NULL, so rows not
    -- yet touched by the sweep are unaffected by this constraint.
    w7_sweep_provenance IS NULL
    OR (
        -- RRO limb: if rro_value is TRUE, rro_signals array must be non-empty.
        -- (IS DISTINCT FROM TRUE evaluates NULL and FALSE identically to 'not TRUE',
        --  so the limb passes for FALSE or NULL emissions without requiring signals.)
        (
            (w7_sweep_provenance ->> 'rro_value')::boolean
                IS DISTINCT FROM TRUE
            OR jsonb_array_length(w7_sweep_provenance -> 'rro_signals') > 0
        )
        AND
        -- SOA limb: if soa_value is TRUE, soa_signals array must be non-empty.
        (
            (w7_sweep_provenance ->> 'soa_value')::boolean
                IS DISTINCT FROM TRUE
            OR jsonb_array_length(w7_sweep_provenance -> 'soa_signals') > 0
        )
    )
) NOT VALID;
