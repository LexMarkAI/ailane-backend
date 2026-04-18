-- Migration: 20260306172930_add_onboarding_intelligence_fields
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_onboarding_intelligence_fields


-- Onboarding intelligence fields on organisations
ALTER TABLE organisations
  ADD COLUMN IF NOT EXISTS region                    text,
  ADD COLUMN IF NOT EXISTS companies_house_number    text,
  ADD COLUMN IF NOT EXISTS recent_claims             boolean,
  ADD COLUMN IF NOT EXISTS recent_claims_count       integer,
  ADD COLUMN IF NOT EXISTS recent_claims_types       text[],
  ADD COLUMN IF NOT EXISTS primary_compliance_concerns text[],
  ADD COLUMN IF NOT EXISTS onboarding_completed      boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS onboarding_completed_at   timestamptz,
  ADD COLUMN IF NOT EXISTS onboarding_data           jsonb DEFAULT '{}';

-- Index for dashboard filtering
CREATE INDEX IF NOT EXISTS idx_orgs_region    ON organisations(region);
CREATE INDEX IF NOT EXISTS idx_orgs_industry  ON organisations(industry);
CREATE INDEX IF NOT EXISTS idx_orgs_onboarded ON organisations(onboarding_completed);

