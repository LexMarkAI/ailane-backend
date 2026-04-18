-- Migration: 20260413134246_kl_surveillance_runner_cron
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: kl_surveillance_runner_cron

-- AILANE-SPEC-KLIA-001 §7 Part III — Automated Legislative Surveillance Framework
-- kl-surveillance-runner: daily orchestrator at 07:15 UTC
-- Reads horizon-* tables, applies Class 1/2/3 triage, writes to kl_legislative_alerts
-- Auth pattern matches horizon-bill-tracker-daily / horizon-si-monitor-daily / horizon-new-bill-scanner-weekly

-- Unschedule any prior revision (idempotent)
SELECT cron.unschedule('kl-surveillance-runner-daily')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kl-surveillance-runner-daily');

SELECT cron.schedule(
    'kl-surveillance-runner-daily',
    '15 7 * * *',
    $$
    SELECT net.http_post(
        url := 'https://cnbsxwtvazfvzmltkuvx.functions.supabase.co/kl-surveillance-runner',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
        ),
        body := '{"source": "pg_cron"}'::jsonb
    ) AS request_id;
    $$
);
