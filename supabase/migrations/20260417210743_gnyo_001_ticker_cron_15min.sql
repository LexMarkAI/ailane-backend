-- Migration: 20260417210743_gnyo_001_ticker_cron_15min
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: gnyo_001_ticker_cron_15min

-- AILANE-CC-BRIEF-GNYO-001-P0a-v2 — Amendment 3
-- Retunes pipeline-ticker-parliamentary cron from daily (once/24h) to every 15 minutes.
-- Rationale: per-run limit is 5 items per table (10 total). Daily cadence leaves fresh
-- intelligence stranded for up to 24h before briefing generation. Director standing
-- preference is full automation; 15-min cadence keeps the ticker institutional-grade
-- real-time while staying inside Supabase 150s idle timeout and Anthropic rate limits.

SELECT cron.unschedule('ticker-parliamentary-daily');

SELECT cron.schedule(
  'ticker-parliamentary-15min',
  '*/15 * * * *',
  $$SELECT net.http_post(
    url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/pipeline-ticker-parliamentary',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body := '{}'::jsonb
  )$$
);
