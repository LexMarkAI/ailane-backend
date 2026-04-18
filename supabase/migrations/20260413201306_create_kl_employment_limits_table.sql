-- Migration: 20260413201306_create_kl_employment_limits_table
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_kl_employment_limits_table


-- PROC-KLMAINT-001 Phase 1 — kl_employment_limits table
-- Single source of truth for dynamic annual rates and limits
-- Eileen queries this table at runtime instead of relying on hardcoded prompt figures

CREATE TABLE IF NOT EXISTS public.kl_employment_limits (
  limit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL CHECK (category IN ('nmw_rates', 'compensation_caps', 'statutory_pay', 'accommodation', 'vento_bands')),
  name TEXT NOT NULL,
  value DECIMAL NOT NULL,
  unit TEXT NOT NULL CHECK (unit IN ('per_hour', 'per_week', 'per_day', 'per_year', 'lump_sum')),
  effective_from DATE NOT NULL,
  effective_to DATE,
  source_instrument TEXT,
  source_url TEXT,
  supersedes_id UUID REFERENCES public.kl_employment_limits(limit_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by TEXT NOT NULL CHECK (updated_by IN ('MANUAL', 'SURVEILLANCE_PIPELINE', 'ANNUAL_AUDIT'))
);

-- Index for runtime queries (current values lookup)
CREATE INDEX IF NOT EXISTS idx_kl_employment_limits_current 
  ON public.kl_employment_limits (category, effective_to) 
  WHERE effective_to IS NULL;

-- Index for historical lookups
CREATE INDEX IF NOT EXISTS idx_kl_employment_limits_history 
  ON public.kl_employment_limits (category, effective_from, effective_to);

-- RLS: service role access (Edge Functions use service role key)
ALTER TABLE public.kl_employment_limits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow service role full access on kl_employment_limits"
  ON public.kl_employment_limits
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated read on kl_employment_limits"
  ON public.kl_employment_limits
  FOR SELECT
  TO authenticated
  USING (true);

COMMENT ON TABLE public.kl_employment_limits IS 'PROC-KLMAINT-001: Dynamic annual rates and limits. Eileen queries at runtime. Updated via surveillance pipeline or manual entry.';

