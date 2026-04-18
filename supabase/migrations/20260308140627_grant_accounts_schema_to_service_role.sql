-- Migration: 20260308140627_grant_accounts_schema_to_service_role
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: grant_accounts_schema_to_service_role


-- Grant service_role full access to the accounts schema
-- Required for PostgREST (Edge Functions, CEO dashboard) to access non-public schema
GRANT USAGE ON SCHEMA accounts TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA accounts TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA accounts TO service_role;

-- Ensure future tables also get the grant automatically
ALTER DEFAULT PRIVILEGES IN SCHEMA accounts
  GRANT ALL ON TABLES TO service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA accounts
  GRANT ALL ON SEQUENCES TO service_role;

