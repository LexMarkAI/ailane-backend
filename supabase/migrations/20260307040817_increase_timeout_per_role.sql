-- Migration: 20260307040817_increase_timeout_per_role
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: increase_timeout_per_role


-- Set timeout per role so PostgREST connections get more time
ALTER ROLE authenticator SET statement_timeout = '120s';
ALTER ROLE authenticated SET statement_timeout = '120s';
ALTER ROLE anon SET statement_timeout = '120s';
ALTER ROLE service_role SET statement_timeout = '120s';

