-- ============================================================================
-- AILANE-SPEC-DMSP-002-W7 §9.3 / §13.3 governance dashboard data views
-- AMD-089 Stage A · CC Build Brief 1 EXEC-01 · §3
-- Migration: w7_create_dashboard_views
-- Purpose : Three views powering the §13.3 four-field latency table,
--           §15.2.1 sweep progress / threshold gate, and §9.3 7-day
--           telemetry rollup. UI wiring is out of scope; the SQL data
--           layer is in scope (Director Decision 4).
-- Brief    : AILANE-CC-BRIEF-001-EXEC-01 (Director-ratified 24 Apr 2026)
-- EXEC-01  : Sweep-progress view now reads provenance / confidence from
--           dedicated w7_sweep_provenance jsonb column (introduced in §2
--           migration 5). llm_raw_response remains text and untouched.
-- Depends  : §2.2 (last_resync_at column, APPLIED), §2.3 (w7_suppression_telemetry,
--           APPLIED), §2 EXEC-01 (w7_sweep_provenance column) must be applied first.
-- ============================================================================

-- §3-A: Resync latency stats (spec §13.3 four first-class fields)
CREATE OR REPLACE VIEW public.v_w7_resync_latency_stats AS
WITH
channel_a AS (
    SELECT
        EXTRACT(EPOCH FROM (now() - last_resync_at)) / 86400.0 AS age_days
    FROM public.tribunal_decisions
    WHERE last_resync_at IS NOT NULL
      AND COALESCE(decision_date, scraped_at::date) < (CURRENT_DATE - INTERVAL '60 days')
),
channel_b AS (
    SELECT
        EXTRACT(EPOCH FROM (now() - last_resync_at)) / 3600.0 AS age_hours
    FROM public.tribunal_decisions
    WHERE last_resync_at IS NOT NULL
      AND COALESCE(decision_date, scraped_at::date) >= (CURRENT_DATE - INTERVAL '60 days')
)
SELECT
    (SELECT round(avg(age_days)::numeric, 2) FROM channel_a) AS resync_mean_latency_days,
    (SELECT round((percentile_cont(0.95) WITHIN GROUP (ORDER BY age_days))::numeric, 2) FROM channel_a) AS resync_p95_latency_days,
    (SELECT round(avg(age_hours)::numeric, 2) FROM channel_b) AS resync_mean_latency_hours,
    (SELECT round((percentile_cont(0.95) WITHIN GROUP (ORDER BY age_hours))::numeric, 2) FROM channel_b) AS resync_p95_latency_hours,
    (SELECT count(*) FROM channel_a) AS channel_a_rows_measured,
    (SELECT count(*) FROM channel_b) AS channel_b_rows_measured,
    (SELECT count(*) FROM public.tribunal_decisions WHERE last_resync_at IS NULL) AS never_resynced_rows,
    (SELECT count(*) FROM public.tribunal_decisions) AS total_decisions,
    now() AS as_of;

COMMENT ON VIEW public.v_w7_resync_latency_stats IS
    'Governance dashboard data for the DMSP-002-W7 §13.3 four first-class latency fields. Channel A (cold archive, excludes last-60-days cohort) reports DAYS. Channel B (recent-60-days cohort) reports HOURS. Targets: A_mean <=20d, A_p95 <=40d, B_mean <=24h, B_p95 <=48h. Sustained breach triggers §9.3 governance review.';

-- §3-B: W7 sweep progress (supports §15.2.1 threshold monitoring)
-- EXEC-01 CHANGE: provenance path moved from (llm_raw_response -> 'w7_sweep')
-- to dedicated column w7_sweep_provenance. Predicate semantics preserved.
CREATE OR REPLACE VIEW public.v_w7_sweep_progress AS
SELECT
    round(100.0 * count(*) FILTER (WHERE restricted_reporting_order IS NOT NULL)
        / NULLIF(count(*), 0), 2) AS c1_rro_coverage_pct,
    round(100.0 * count(*) FILTER (WHERE soa_1992_identified IS NOT NULL)
        / NULLIF(count(*), 0), 2) AS c2_soa_coverage_pct,
    round(100.0 * count(*) FILTER (WHERE
        COALESCE((w7_sweep_provenance ->> 'rro_confidence')::numeric, 1.0) < 0.75
        OR COALESCE((w7_sweep_provenance ->> 'soa_confidence')::numeric, 1.0) < 0.75)
        / NULLIF(count(*), 0), 2) AS c3_manual_review_pct,
    CASE
        WHEN round(100.0 * count(*) FILTER (WHERE restricted_reporting_order IS NOT NULL)
            / NULLIF(count(*), 0), 2) >= 95.0
         AND round(100.0 * count(*) FILTER (WHERE soa_1992_identified IS NOT NULL)
            / NULLIF(count(*), 0), 2) >= 95.0
         AND round(100.0 * count(*) FILTER (WHERE
            COALESCE((w7_sweep_provenance ->> 'rro_confidence')::numeric, 1.0) < 0.75
            OR COALESCE((w7_sweep_provenance ->> 'soa_confidence')::numeric, 1.0) < 0.75)
            / NULLIF(count(*), 0), 2) <= 1.0
        THEN TRUE ELSE FALSE
    END AS threshold_satisfied,
    count(*) FILTER (WHERE enrichment_scope = 'full') AS full_scope_rows,
    count(*) FILTER (WHERE enrichment_scope = 'w7_only') AS w7_only_scope_rows,
    count(*) AS total_enriched_rows,
    count(*) FILTER (WHERE w7_sweep_provenance IS NOT NULL) AS swept_rows,
    now() AS as_of
FROM public.tribunal_enrichment;

COMMENT ON VIEW public.v_w7_sweep_progress IS
    'Governance dashboard data for the DMSP-002-W7 §15.2.1 threshold verification. threshold_satisfied is TRUE when C1 >= 95 AND C2 >= 95 AND C3 <= 1. Chairman runs this before authorising Stage B. Plateau clause at §15.2.1 applies if threshold_satisfied remains FALSE for 14 days post-sweep. Provenance reads from w7_sweep_provenance (EXEC-01).';

-- §3-C: 7-day telemetry rollup (spec §9.3 governance review input)
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
