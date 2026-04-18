-- Migration: 20260312223250_add_one_time_scan_tier_to_portal_sessions
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_one_time_scan_tier_to_portal_sessions


-- Drop existing tier check constraint and replace with expanded set
ALTER TABLE compliance_portal_sessions
  DROP CONSTRAINT IF EXISTS compliance_portal_sessions_tier_check;

ALTER TABLE compliance_portal_sessions
  ADD CONSTRAINT compliance_portal_sessions_tier_check
  CHECK (tier = ANY (ARRAY['flash','full','one_time_scan','operational','governance','institutional']));

