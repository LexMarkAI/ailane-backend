-- Migration: 20260405155826_create_welsh_public_sector_workforce_reference
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_welsh_public_sector_workforce_reference


-- Welsh Public Sector Workforce Reference Table
-- Authoritative headcount data from ONS, StatsWales, and published annual reports
-- Enables per-employer and per-sub-sector rate analysis

CREATE TABLE IF NOT EXISTS public.welsh_public_sector_workforce (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  body_name text NOT NULL,
  body_sub_type text NOT NULL,
  body_category text NOT NULL,
  headcount_estimate integer NOT NULL,
  headcount_source text NOT NULL,
  headcount_date date NOT NULL,
  employer_master_pattern text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_welsh_workforce_sub_type 
  ON public.welsh_public_sector_workforce (body_sub_type);
CREATE INDEX IF NOT EXISTS idx_welsh_workforce_category 
  ON public.welsh_public_sector_workforce (body_category);

COMMENT ON TABLE public.welsh_public_sector_workforce IS 'Welsh public sector workforce reference data from ONS, StatsWales, and published sources. Used as denominators for per-employer tribunal rate analysis.';

