-- ============================================================================
-- AILANE-SPEC-DMSP-002-W7 §12.1
-- AMD-089 Stage A · CC Build Brief 1 · §2.1
-- Migration: w7_add_enrichment_scope
-- Purpose : Add enrichment_scope column + index to tribunal_enrichment so the
--           Haiku retrospective sweep can mark rows emitted under the W7-only
--           path without conflating them with full-enrichment rows.
-- Brief    : AILANE-CC-BRIEF-001 v1.1 (ratified CEO-RAT-AMD-089, 24 Apr 2026)
-- Scope    : Day-zero clean slate — Chairman §0.1 confirms column ABSENT and
--           idx_enrichment_scope ABSENT prior to apply.
-- ============================================================================

ALTER TABLE public.tribunal_enrichment
    ADD COLUMN enrichment_scope TEXT NOT NULL DEFAULT 'full'
        CHECK (enrichment_scope IN ('full', 'w7_only'));

-- Index to accelerate partition queries used by v_enrichment_completeness_v2
-- and v_enrichment_completion_register_v2
CREATE INDEX IF NOT EXISTS idx_enrichment_scope
    ON public.tribunal_enrichment (enrichment_scope);
