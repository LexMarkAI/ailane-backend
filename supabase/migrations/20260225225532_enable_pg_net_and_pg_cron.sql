-- Migration: 20260225225532_enable_pg_net_and_pg_cron
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: enable_pg_net_and_pg_cron


-- Enable pg_net for HTTP calls from triggers
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
