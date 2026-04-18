-- Migration: 20260414080546_add_deleted_at_to_compliance_uploads
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_deleted_at_to_compliance_uploads


-- ============================================================
-- Sprint F Tidy-Up: Add deleted_at to compliance_uploads
-- Enables soft-delete for CC-sourced vault documents
-- Mirrors kl_vault_documents pattern (AMD-050 §5)
-- ============================================================

-- 1. Add the column
ALTER TABLE public.compliance_uploads
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 2. Update the authenticated SELECT policy to exclude soft-deleted rows
-- Drop the existing policy and recreate with deleted_at filter
DROP POLICY IF EXISTS "Authenticated read own org uploads" ON public.compliance_uploads;

CREATE POLICY "Authenticated read own org uploads"
  ON public.compliance_uploads
  FOR SELECT
  TO authenticated
  USING (
    organisation_id = get_my_org_id()
    AND deleted_at IS NULL
  );

-- 3. Portal read policy also needs the filter
DROP POLICY IF EXISTS "portal_read" ON public.compliance_uploads;

CREATE POLICY "portal_read"
  ON public.compliance_uploads
  FOR SELECT
  TO authenticated
  USING (
    organisation_id = '00000001-0000-0000-0000-000000000001'::uuid
    AND deleted_at IS NULL
  );

