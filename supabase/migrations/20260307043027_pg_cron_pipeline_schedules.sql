-- Migration: 20260307043027_pg_cron_pipeline_schedules
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: pg_cron_pipeline_schedules


-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- GOV.UK Tribunals: 06:00 UTC Mon-Fri
SELECT cron.schedule(
  'govuk-tribunals-daily',
  '0 6 * * 1-5',
  $$SELECT net.http_post(url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/pipeline-govuk-tribunals', headers := '{"Content-Type":"application/json"}'::jsonb, body := '{}'::jsonb)$$
);

-- GOV.UK Employment News: 07:00 UTC daily
SELECT cron.schedule(
  'govuk-news-daily',
  '0 7 * * *',
  $$SELECT net.http_post(url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/pipeline-govuk-news', headers := '{"Content-Type":"application/json"}'::jsonb, body := '{}'::jsonb)$$
);

-- Parliament Bills: 08:00 UTC daily
SELECT cron.schedule(
  'parliament-bills-daily',
  '0 8 * * *',
  $$SELECT net.http_post(url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/pipeline-parliament-bills', headers := '{"Content-Type":"application/json"}'::jsonb, body := '{}'::jsonb)$$
);

-- Select Committees: 08:30 UTC daily
SELECT cron.schedule(
  'parliament-committees-daily',
  '30 8 * * *',
  $$SELECT net.http_post(url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/pipeline-parliament-committees', headers := '{"Content-Type":"application/json"}'::jsonb, body := '{}'::jsonb)$$
);

-- Hansard: 09:00 UTC daily
SELECT cron.schedule(
  'parliament-hansard-daily',
  '0 9 * * *',
  $$SELECT net.http_post(url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/pipeline-hansard', headers := '{"Content-Type":"application/json"}'::jsonb, body := '{}'::jsonb)$$
);

-- BBC Parliament: 10:00 UTC daily
SELECT cron.schedule(
  'bbc-parliament-daily',
  '0 10 * * *',
  $$SELECT net.http_post(url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/pipeline-bbc-parliament', headers := '{"Content-Type":"application/json"}'::jsonb, body := '{}'::jsonb)$$
);

-- Ticker briefings: 11:00 UTC daily (after all sources have run)
SELECT cron.schedule(
  'ticker-parliamentary-daily',
  '0 11 * * *',
  $$SELECT net.http_post(url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/pipeline-ticker-parliamentary', headers := '{"Content-Type":"application/json"}'::jsonb, body := '{}'::jsonb)$$
);

