-- ============================================================================
-- AILANE-SPEC-DMSP-002-W7 §13.3 scheduling (COP P1-1 + P1-3/P1-4 + P2-1 applied)
-- AMD-089 Stage A · CC Build Brief 1 · v1.1 · §2.9
-- Migration: w7_create_cron_jobs
-- Purpose : Schedule the four Stage A cron jobs —
--             1. w7-hmcts-resync-channel-a      (cold archive, nightly 02:00 UTC)
--             2. w7-hmcts-resync-channel-b      (recent 60d cohort, nightly 03:00 UTC)
--             3. w7-layer1-aggregate-weekly     (COP P1-1, Mon 05:00 UTC)
--             4. w7-telemetry-weekly-purge      (12m retention, Sun 04:00 UTC)
-- Brief    : AILANE-CC-BRIEF-001 v1.1 (ratified CEO-RAT-AMD-089, 24 Apr 2026)
-- Token    : COP P2-1 token {{SERVICE_ROLE_KEY_SETTING}} resolved to
--           'app.settings.service_role_key' per Chairman §0.4 audit (both
--           conventions in estate; newer convention adopted).
-- Depends  : §2.3 (w7_suppression_telemetry table) for the Layer 1 aggregate
--           insert. The w7-hmcts-resync Edge Function MUST be deployed via
--           Path A MCP (Director/Chairman) before the first cron fires.
-- Non-dup  : Chairman §0.5 confirms all four job names ABSENT in cron.job.
-- Collisions: §0.5 confirms purge_cc_telemetry_weekly runs Sun 03:00; this
--           migration schedules w7-telemetry-weekly-purge at Sun 04:00 to
--           avoid queue contention.
-- ============================================================================

-- Channel A — 02:00 UTC daily. Cron fires the FIRST batch of the self-chain;
-- the EF self-enqueues subsequent batches via EdgeRuntime.waitUntil per §2.8.2.
SELECT cron.schedule(
  'w7-hmcts-resync-channel-a',
  '0 2 * * *',
  $$
  SELECT net.http_post(
    url := 'https://cnbsxwtvazfvzmltkuvx.functions.supabase.co/w7-hmcts-resync',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := '{"channel":"A","limit":150,"chain_depth":0}'::jsonb
  ) AS request_id;
  $$
);

-- Channel B — 03:00 UTC daily. Same batched pattern; the EF self-chains
-- through the last-60-days cohort.
SELECT cron.schedule(
  'w7-hmcts-resync-channel-b',
  '0 3 * * *',
  $$
  SELECT net.http_post(
    url := 'https://cnbsxwtvazfvzmltkuvx.functions.supabase.co/w7-hmcts-resync',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := '{"channel":"B","limit":150,"chain_depth":0}'::jsonb
  ) AS request_id;
  $$
);

-- Weekly Layer 1 aggregate capture (COP P1-1 resolution; spec §9.2 Layer 1 row)
-- Schedule: Monday 05:00 UTC — alignment with existing estate weekly slots;
-- avoids conflict with the existing purge_cc_telemetry Sunday 03:00 slot.
-- Emits ONE row into w7_suppression_telemetry per week with
-- layer='layer_1', flag_class='aggregate'. The event_count is the row-count
-- differential between tribunal_enrichment and tribunal_intelligence
-- (spec §9.2: "computed as a weekly aggregate by comparing total rows in
-- tribunal_enrichment with total rows visible through tribunal_intelligence").
SELECT cron.schedule(
  'w7-layer1-aggregate-weekly',
  '0 5 * * 1',
  $$
  INSERT INTO public.w7_suppression_telemetry
    (layer, flag_class, caller_surface, event_count, event_bucket_start, event_bucket_end)
  SELECT
      'layer_1',
      'aggregate',
      'view:tribunal_intelligence',
      GREATEST(
          (SELECT count(*) FROM public.tribunal_enrichment)
          - (SELECT count(*) FROM public.tribunal_intelligence),
          0
      ),
      date_trunc('week', now()) - INTERVAL '7 days',
      date_trunc('week', now());
  $$
);

-- Weekly purge of w7_suppression_telemetry (12-month retention per spec §9.4)
-- Schedule: Sunday 04:00 UTC (avoiding the 03:00 Sunday weekly slot already
-- used by purge_cc_telemetry per Chairman §0.5 collision advisory).
SELECT cron.schedule(
  'w7-telemetry-weekly-purge',
  '0 4 * * 0',
  $$
  DELETE FROM public.w7_suppression_telemetry
  WHERE event_bucket_start < (now() - INTERVAL '12 months');
  $$
);
