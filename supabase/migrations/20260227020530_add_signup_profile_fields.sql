-- Migration: 20260227020530_add_signup_profile_fields
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_signup_profile_fields


-- Add optional profile fields to early_access_signups
ALTER TABLE early_access_signups
  ADD COLUMN IF NOT EXISTS company_name text,
  ADD COLUMN IF NOT EXISTS job_title text,
  ADD COLUMN IF NOT EXISTS employee_count text CHECK (employee_count IN ('1-49','50-99','100-199','200-499','500+')),
  ADD COLUMN IF NOT EXISTS sector text,
  ADD COLUMN IF NOT EXISTS uk_region text,
  ADD COLUMN IF NOT EXISTS multinational boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS compliance_concerns text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS full_name text;
