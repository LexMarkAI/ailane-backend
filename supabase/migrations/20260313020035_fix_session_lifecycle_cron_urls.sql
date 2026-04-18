-- Migration: 20260313020035_fix_session_lifecycle_cron_urls
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_session_lifecycle_cron_urls


-- Remove old cron jobs and re-add with hardcoded URL
SELECT cron.unschedule('portal-session-48h-reminder');
SELECT cron.unschedule('portal-session-7day-refund');

SELECT cron.schedule(
  'portal-session-48h-reminder',
  '0 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/session-lifecycle',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer ' || current_setting('app.service_role_key', true) || '"}'::jsonb,
    body := '{"action":"reminder"}'::jsonb
  );
  $$
);

SELECT cron.schedule(
  'portal-session-7day-refund',
  '0 2 * * *',
  $$
  SELECT net.http_post(
    url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/session-lifecycle',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer ' || current_setting('app.service_role_key', true) || '"}'::jsonb,
    body := '{"action":"refund"}'::jsonb
  );
  $$
);

