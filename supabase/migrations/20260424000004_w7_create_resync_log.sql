-- ============================================================================
-- AILANE-SPEC-DMSP-002-W7 §13.5
-- AMD-089 Stage A · CC Build Brief 1 · §2.4
-- Migration: w7_create_resync_log
-- Purpose : Create w7_resync_log as the audit trail for every HMCTS resync
--           event. One row per (decision_id, resync_at); change_detected
--           boolean captures whether the stored content_hash diverged from
--           the refetched source hash. RRO/SOA _before/_after columns
--           reserved for downstream re-enrichment workers (§13.4).
-- Brief    : AILANE-CC-BRIEF-001 v1.1 (ratified CEO-RAT-AMD-089, 24 Apr 2026)
-- Scope    : Day-zero clean slate — Chairman §0.1 confirms table ABSENT.
-- Note     : Brief 1 adds three operational indices not in spec §13.5
--           (required for §2.6 dashboard queries at scale); the table shape
--           itself is verbatim from spec.
-- ============================================================================

CREATE TABLE public.w7_resync_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    decision_id uuid NOT NULL REFERENCES public.tribunal_decisions(id),
    resync_at timestamptz NOT NULL DEFAULT now(),
    hash_before text,
    hash_after  text,
    change_detected boolean NOT NULL,
    rro_before boolean,
    rro_after boolean,
    soa_before boolean,
    soa_after boolean
);

-- Operational indices (not in spec §13.5 but required for §2.6 dashboard
-- queries to perform acceptably at scale)
CREATE INDEX IF NOT EXISTS idx_w7_resync_log_resync_at
    ON public.w7_resync_log (resync_at DESC);
CREATE INDEX IF NOT EXISTS idx_w7_resync_log_decision_id
    ON public.w7_resync_log (decision_id);
CREATE INDEX IF NOT EXISTS idx_w7_resync_log_change_detected
    ON public.w7_resync_log (change_detected) WHERE change_detected = TRUE;

-- RLS posture: service_role only.
ALTER TABLE public.w7_resync_log ENABLE ROW LEVEL SECURITY;
