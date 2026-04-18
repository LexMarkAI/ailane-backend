-- Migration: 20260313015924_add_session_reminder_and_refund_cron
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_session_reminder_and_refund_cron


-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 48-hour reminder: runs every hour, finds paid sessions 47-49h old, marks reminder_sent
ALTER TABLE compliance_portal_sessions 
  ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ;

-- Schedule 48h reminder check (runs every hour)
SELECT cron.schedule(
  'portal-session-48h-reminder',
  '0 * * * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/session-lifecycle',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    ),
    body := '{"action":"reminder"}'::jsonb
  );
  $$
);

-- Schedule 7-day auto-refund check (runs daily at 02:00 UTC)
SELECT cron.schedule(
  'portal-session-7day-refund',
  '0 2 * * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/session-lifecycle',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    ),
    body := '{"action":"refund"}'::jsonb
  );
  $$
);

