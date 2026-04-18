-- Migration: 20260314002326_qai_006_weekly_audit_cron
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qai_006_weekly_audit_cron

-- Enable pg_cron if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant usage to postgres role
GRANT USAGE ON SCHEMA cron TO postgres;

-- Schedule qai-weekly-audit every Sunday at 07:00 UTC
-- Removes any existing schedule for this job first to avoid duplicates
SELECT cron.unschedule('qai-weekly-audit') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'qai-weekly-audit'
);

SELECT cron.schedule(
  'qai-weekly-audit',
  '0 7 * * 0',
  $$
  SELECT net.http_post(
    url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/qai-weekly-audit',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.service_role_key', true) || '"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
