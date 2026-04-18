-- Migration: 20260304163058_compliance_checker_rls_policies
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: compliance_checker_rls_policies


-- =============================================================
-- COMPLIANCE CHECKER: Row Level Security Policies
-- Pattern: get_my_org_id() for client reads; service_role for writes
-- =============================================================

-- 1. compliance_uploads RLS
ALTER TABLE compliance_uploads ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read their own organisation's uploads
CREATE POLICY "Authenticated read own org uploads"
  ON compliance_uploads FOR SELECT
  TO authenticated
  USING (organisation_id = get_my_org_id());

-- Authenticated users can insert uploads for their own organisation
CREATE POLICY "Authenticated insert own org uploads"
  ON compliance_uploads FOR INSERT
  TO authenticated
  WITH CHECK (organisation_id = get_my_org_id());

-- Service role has full access (for backend processing pipeline)
CREATE POLICY "Service role manage uploads"
  ON compliance_uploads FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 2. compliance_findings RLS
ALTER TABLE compliance_findings ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read findings for their own organisation's uploads
CREATE POLICY "Authenticated read own org findings"
  ON compliance_findings FOR SELECT
  TO authenticated
  USING (
    upload_id IN (
      SELECT id FROM compliance_uploads 
      WHERE organisation_id = get_my_org_id()
    )
  );

-- Service role has full access (processing pipeline writes findings)
CREATE POLICY "Service role manage findings"
  ON compliance_findings FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 3. regulatory_requirements RLS
-- Reference data: readable by all authenticated users, writable by service role only
ALTER TABLE regulatory_requirements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated read requirements"
  ON regulatory_requirements FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Anon read requirements"
  ON regulatory_requirements FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Service role manage requirements"
  ON regulatory_requirements FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 4. Storage policies for compliance-documents bucket
CREATE POLICY "Users upload own org docs"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'compliance-documents'
    AND (storage.foldername(name))[1] = get_my_org_id()::text
  );

CREATE POLICY "Users read own org docs"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'compliance-documents'
    AND (storage.foldername(name))[1] = get_my_org_id()::text
  );

CREATE POLICY "Service role manage compliance docs"
  ON storage.objects FOR ALL
  TO service_role
  USING (bucket_id = 'compliance-documents')
  WITH CHECK (bucket_id = 'compliance-documents');

