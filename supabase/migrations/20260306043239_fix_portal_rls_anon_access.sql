-- Migration: 20260306043239_fix_portal_rls_anon_access
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_portal_rls_anon_access


-- Drop and recreate portal_read policies explicitly granting to anon role

-- compliance_uploads
DROP POLICY IF EXISTS portal_read ON compliance_uploads;
CREATE POLICY portal_read ON compliance_uploads
  FOR SELECT TO anon
  USING (organisation_id = '00000001-0000-0000-0000-000000000001'::uuid);

-- compliance_findings
DROP POLICY IF EXISTS portal_read ON compliance_findings;
CREATE POLICY portal_read ON compliance_findings
  FOR SELECT TO anon
  USING (
    upload_id IN (
      SELECT id FROM compliance_uploads
      WHERE organisation_id = '00000001-0000-0000-0000-000000000001'::uuid
    )
  );

