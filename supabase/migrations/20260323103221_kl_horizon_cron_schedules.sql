-- Migration: 20260323103221_kl_horizon_cron_schedules
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: kl_horizon_cron_schedules


-- ================================================================
-- AILANE — Legislative Horizon: Automated Cron Schedules
-- Three distinct pipelines, staggered after the daily freshness scan:
--   04:00 UTC — kltr-daily-freshness-scan (existing)
--   05:00 UTC — horizon-bill-tracker (daily)
--   06:00 UTC — horizon-si-monitor (daily)
--   07:00 UTC — horizon-new-bill-scanner (weekly, Monday only)
-- ================================================================

-- 1. Daily Bill Stage Tracker — 05:00 UTC
SELECT cron.schedule(
    'horizon-bill-tracker-daily',
    '0 5 * * *',
    $$
    SELECT net.http_post(
        url := 'https://cnbsxwtvazfvzmltkuvx.functions.supabase.co/horizon-bill-tracker',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
        ),
        body := '{"source": "pg_cron"}'::jsonb
    ) AS request_id;
    $$
);

-- 2. Daily SI Monitor — 06:00 UTC
SELECT cron.schedule(
    'horizon-si-monitor-daily',
    '0 6 * * *',
    $$
    SELECT net.http_post(
        url := 'https://cnbsxwtvazfvzmltkuvx.functions.supabase.co/horizon-si-monitor',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
        ),
        body := '{"source": "pg_cron"}'::jsonb
    ) AS request_id;
    $$
);

-- 3. Weekly New Bill Scanner — Monday 07:00 UTC
SELECT cron.schedule(
    'horizon-new-bill-scanner-weekly',
    '0 7 * * 1',
    $$
    SELECT net.http_post(
        url := 'https://cnbsxwtvazfvzmltkuvx.functions.supabase.co/horizon-new-bill-scanner',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
        ),
        body := '{"source": "pg_cron"}'::jsonb
    ) AS request_id;
    $$
);

