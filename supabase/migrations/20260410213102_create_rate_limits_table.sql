-- Migration: 20260410213102_create_rate_limits_table
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_rate_limits_table


CREATE TABLE IF NOT EXISTS rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ip_address TEXT NOT NULL,
  function_name TEXT NOT NULL,
  identifier TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_ip_fn_created 
  ON rate_limits (ip_address, function_name, created_at);

CREATE INDEX IF NOT EXISTS idx_rate_limits_identifier_created
  ON rate_limits (identifier, created_at);

-- Auto-cleanup: delete entries older than 1 hour
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;

-- No user-facing RLS needed — only service_role writes/reads

