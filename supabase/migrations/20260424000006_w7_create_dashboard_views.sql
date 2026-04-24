-- ============================================================================
-- AILANE-SPEC-DMSP-002-W7 §9.3 / §13.3 governance dashboard data views
-- AMD-089 Stage A · CC Build Brief 1 · §2.6
-- Migration: w7_create_dashboard_views
-- Purpose : Three views powering the §13.3 four-field latency table,
--           §15.2.1 sweep progress / threshold gate, and §9.3 7-day
--           telemetry rollup. UI wiring is out of scope; the SQL data
--           layer is in scope (Director Decision 4).
-- Brief    : AILANE-CC-BRIEF-001 v1.1 (ratified CEO-RAT-AMD-089, 24 Apr 2026)
-- Depends  : §2.2 (last_resync_at column) and §2.3 (w7_suppression_telemetry)
--           must be applied first. Ordering preserved by filename timestamp.
-- ============================================================================

-- §2.6-A: Resync latency stats (spec §13.3 four first-class fields)
-- Channel A = cold archive (excludes last-60-days cohort, measured in DAYS)
-- Channel B = recent cohort (only last-60-days rows, measured in HOURS)
CREATE OR REPLACE VIEW public.v_w7_resync_latency_stats AS
WITH
channel_a AS (
    -- Cold archive: rows NOT in the recent-60-day cohort
    SELECT
        EXTRACT(EPOCH FROM (now() - last_resync_at)) / 86400.0 AS age_days
    FROM public.tribunal_decisions
    WHERE last_resync_at IS NOT NULL
      AND COALESCE(decision_date, scraped_at::date) < (CURRENT_DATE - INTERVAL '60 days')
),
channel_b AS (
    -- Recent cohort: rows IN the last-60-day window
    SELECT
        EXTRACT(EPOCH FROM (now() - last_resync_at)) / 3600.0 AS age_hours
    FROM public.tribunal_decisions
    WHERE last_resync_at IS NOT NULL
      AND COALESCE(decision_date, scraped_at::date) >= (CURRENT_DATE - INTERVAL '60 days')
)
SELECT
    -- Channel A — cold archive, days
    (SELECT round(avg(age_days)::numeric, 2)
        FROM channel_a) AS resync_mean_latency_days,
    (SELECT round((percentile_cont(0.95) WITHIN GROUP (ORDER BY age_days))::numeric, 2)
        FROM channel_a) AS resync_p95_latency_days,
    -- Channel B — recent, hours
    (SELECT round(avg(age_hours)::numeric, 2)
        FROM channel_b) AS resync_mean_latency_hours,
    (SELECT round((percentile_cont(0.95) WITHIN GROUP (ORDER BY age_hours))::numeric, 2)
        FROM channel_b) AS resync_p95_latency_hours,
    -- Supporting context
    (SELECT count(*) FROM channel_a) AS channel_a_rows_measured,
    (SELECT count(*) FROM channel_b) AS channel_b_rows_measured,
    (SELECT count(*) FROM public.tribunal_decisions WHERE last_resync_at IS NULL) AS never_resynced_rows,
    (SELECT count(*) FROM public.tribunal_decisions) AS total_decisions,
    now() AS as_of;

COMMENT ON VIEW public.v_w7_resync_latency_stats IS
    'Governance dashboard data for the DMSP-002-W7 §13.3 four first-class latency fields. Channel A (cold archive, excludes last-60-days cohort) reports DAYS. Channel B (recent-60-days cohort) reports HOURS. Targets: A_mean <=20d, A_p95 <=40d, B_mean <=24h, B_p95 <=48h. Sustained breach triggers §9.3 governance review.';

-- §2.6-B: W7 sweep progress (supports §15.2.1 threshold monitoring)
CREATE OR REPLACE VIEW public.v_w7_sweep_progress AS
SELECT
    -- C1: RRO coverage (% of enriched rows with explicit RRO value, any scope)
    round(100.0 * count(*) FILTER (WHERE restricted_reporting_order IS NOT NULL)
        / NULLIF(count(*), 0), 2) AS c1_rro_coverage_pct,
    -- C2: SOA coverage (% of enriched rows with explicit SOA value, any scope)
    round(100.0 * count(*) FILTER (WHERE soa_1992_identified IS NOT NULL)
        / NULLIF(count(*), 0), 2) AS c2_soa_coverage_pct,
    -- C3: Manual-review backlog (% with either confidence < 0.75)
    -- NOTE: Per handover §7 concrete query / spec §15.2.1 semantics (Director Decision 2).
    round(100.0 * count(*) FILTER (WHERE
        COALESCE((llm_raw_response -> 'w7_sweep' ->> 'rro_confidence')::numeric, 1.0) < 0.75
        OR COALESCE((llm_raw_response -> 'w7_sweep' ->> 'soa_confidence')::numeric, 1.0) < 0.75)
        / NULLIF(count(*), 0), 2) AS c3_manual_review_pct,
    -- Threshold gate (TRUE only when all three conditions hold)
    CASE
        WHEN round(100.0 * count(*) FILTER (WHERE restricted_reporting_order IS NOT NULL)
            / NULLIF(count(*), 0), 2) >= 95.0
         AND round(100.0 * count(*) FILTER (WHERE soa_1992_identified IS NOT NULL)
            / NULLIF(count(*), 0), 2) >= 95.0
         AND round(100.0 * count(*) FILTER (WHERE
            COALESCE((llm_raw_response -> 'w7_sweep' ->> 'rro_confidence')::numeric, 1.0) < 0.75
            OR COALESCE((llm_raw_response -> 'w7_sweep' ->> 'soa_confidence')::numeric, 1.0) < 0.75)
            / NULLIF(count(*), 0), 2) <= 1.0
        THEN TRUE ELSE FALSE
    END AS threshold_satisfied,
    -- Scope breakdown
    count(*) FILTER (WHERE enrichment_scope = 'full') AS full_scope_rows,
    count(*) FILTER (WHERE enrichment_scope = 'w7_only') AS w7_only_scope_rows,
    count(*) AS total_enriched_rows,
    -- Sweep completion indicators
    count(*) FILTER (WHERE llm_raw_response -> 'w7_sweep' IS NOT NULL) AS swept_rows,
    now() AS as_of
FROM public.tribunal_enrichment;

COMMENT ON VIEW public.v_w7_sweep_progress IS
    'Governance dashboard data for the DMSP-002-W7 §15.2.1 threshold verification. threshold_satisfied is TRUE when C1 >= 95 AND C2 >= 95 AND C3 <= 1. Chairman runs this before authorising Stage B. Plateau clause at §15.2.1 applies if threshold_satisfied remains FALSE for 14 days post-sweep.';

-- §2.6-C: 7-day telemetry rollup (spec §9.3 governance review input)
CREATE OR REPLACE VIEW public.v_w7_telemetry_rollup AS
SELECT
    layer,
    flag_class,
    caller_surface,
    sum(event_count) AS total_events_7d,
    count(DISTINCT date_trunc('hour', event_bucket_start)) AS distinct_hours_with_events,
    min(event_bucket_start) AS earliest_bucket,
    max(event_bucket_end) AS latest_bucket
FROM public.w7_suppression_telemetry
WHERE event_bucket_start >= (now() - INTERVAL '7 days')
GROUP BY layer, flag_class, caller_surface
ORDER BY layer, flag_class, caller_surface;

COMMENT ON VIEW public.v_w7_telemetry_rollup IS
    'Governance dashboard data for the DMSP-002-W7 §9.3 monthly telemetry review. Rolling 7-day window. Anomaly signals per §9.3: persistent non-zero Layer 4 firing -> Layer 1/2 coverage gap; sudden Layer 2 spike -> new caller bypassing tribunal_intelligence; all-layers-zero -> filter may not be firing.';
