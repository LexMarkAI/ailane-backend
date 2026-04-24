-- ============================================================================
-- AILANE-SPEC-DMSP-002-W7 §9.1
-- AMD-089 Stage A · CC Build Brief 1 · §2.3
-- Migration: w7_create_suppression_telemetry
-- Purpose : Create the layered suppression telemetry register. Records one
--           row per distinct suppression event (or weekly aggregate for
--           Layer 1). Retention is 12 months; weekly purge scheduled in
--           §2.9 w7-telemetry-weekly-purge.
-- Brief    : AILANE-CC-BRIEF-001 v1.1 (ratified CEO-RAT-AMD-089, 24 Apr 2026)
-- Scope    : Day-zero clean slate — Chairman §0.1 confirms table ABSENT.
-- ============================================================================

CREATE TABLE public.w7_suppression_telemetry (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    layer text NOT NULL CHECK (layer IN ('layer_1','layer_2','layer_3','layer_4')),
    flag_class text NOT NULL CHECK (flag_class IN ('rro','soa_1992','both','aggregate','unknown')),
    caller_surface text NOT NULL,
    event_count integer NOT NULL DEFAULT 1,
    event_bucket_start timestamptz NOT NULL,
    event_bucket_end   timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    -- A Layer 1 capture cannot distinguish flag_class per-row (the mechanism
    -- at §9.2 is a periodic row-count differential), so Layer 1 rows MUST
    -- carry flag_class='aggregate'. Layer 2, 3, and 4 rows MUST NOT use
    -- flag_class='aggregate' and SHOULD use 'rro', 'soa_1992', or 'both'
    -- where determinable; 'unknown' is reserved for Layer 4 pattern firings
    -- where the pattern family cannot be decisively resolved to rro or soa_1992.
    CONSTRAINT chk_layer1_flag_class_is_aggregate
        CHECK (layer <> 'layer_1' OR flag_class = 'aggregate'),
    CONSTRAINT chk_other_layers_not_aggregate
        CHECK (layer = 'layer_1' OR flag_class <> 'aggregate')
);

CREATE INDEX IF NOT EXISTS idx_w7_telemetry_bucket
    ON public.w7_suppression_telemetry (event_bucket_start, event_bucket_end);
CREATE INDEX IF NOT EXISTS idx_w7_telemetry_caller
    ON public.w7_suppression_telemetry (caller_surface);
CREATE INDEX IF NOT EXISTS idx_w7_telemetry_layer_class
    ON public.w7_suppression_telemetry (layer, flag_class);

-- RLS posture: service_role only. Telemetry is never client-read.
ALTER TABLE public.w7_suppression_telemetry ENABLE ROW LEVEL SECURITY;
-- No policies created: default-deny; only service_role bypasses RLS.
