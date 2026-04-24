-- ============================================================================
-- AILANE-SPEC-DMSP-002-W7 §13.4 step 1
-- AMD-089 Stage A · CC Build Brief 1 · v1.1 · §2.8.1
-- Migration: w7_add_resync_change_flag
-- Purpose : Add resync_change_detected_at timestamp to tribunal_decisions.
--           Populated by the w7-hmcts-resync EF when a hash mismatch is
--           detected; consumed by downstream re-enrichment workers (out of
--           Brief 1 scope) to trigger targeted re-scrape / re-enrichment /
--           Haiku re-sweep.
-- Brief    : AILANE-CC-BRIEF-001 v1.1 (ratified CEO-RAT-AMD-089, 24 Apr 2026)
-- Scope    : Day-zero clean slate — column and idx_tribunal_decisions_change_pending
--           both absent per Chairman §0.1 step 8.
-- ============================================================================

ALTER TABLE public.tribunal_decisions
    ADD COLUMN IF NOT EXISTS resync_change_detected_at timestamptz NULL;

CREATE INDEX IF NOT EXISTS idx_tribunal_decisions_change_pending
    ON public.tribunal_decisions (resync_change_detected_at)
    WHERE resync_change_detected_at IS NOT NULL;
