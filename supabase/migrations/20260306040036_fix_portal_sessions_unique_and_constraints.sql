-- Migration: 20260306040036_fix_portal_sessions_unique_and_constraints
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_portal_sessions_unique_and_constraints


-- Add UNIQUE constraint on stripe_session_id (required for upsert to work)
ALTER TABLE compliance_portal_sessions
  ADD CONSTRAINT compliance_portal_sessions_stripe_session_id_key 
  UNIQUE (stripe_session_id);

-- Make company_name nullable (Stripe doesn't always provide it)
ALTER TABLE compliance_portal_sessions 
  ALTER COLUMN company_name DROP NOT NULL;

-- Make name nullable too (Stripe Payment Links don't collect names by default)
ALTER TABLE compliance_portal_sessions 
  ALTER COLUMN name DROP NOT NULL;

