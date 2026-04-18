-- Migration: 20260306024125_portal_session_tokens_and_org
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: portal_session_tokens_and_org


-- ── 1. Add stripe_session_id lookup index to compliance_portal_sessions ──
CREATE INDEX IF NOT EXISTS idx_cps_stripe_session 
  ON compliance_portal_sessions(stripe_session_id)
  WHERE stripe_session_id IS NOT NULL;

-- ── 2. Create dedicated portal organisation ──
INSERT INTO organisations (id, name, industry, plan, jurisdiction, primary_jurisdiction_code, created_at)
VALUES (
  '00000001-0000-0000-0000-000000000001',
  'Ailane Public Portal',
  'Regulatory Intelligence',
  'trial',
  'UK',
  'GB',
  now()
)
ON CONFLICT (id) DO NOTHING;

-- ── 3. Allow anon SELECT on compliance_portal_sessions by stripe_session_id ──
-- (Portal needs to verify payment without auth)
CREATE POLICY "portal_verify_by_session" ON compliance_portal_sessions
  FOR SELECT TO anon
  USING (stripe_session_id IS NOT NULL);

-- ── 4. Allow anon SELECT on compliance_uploads (for status polling) ──
-- Scoped to portal org only
ALTER TABLE compliance_uploads ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'compliance_uploads' AND policyname = 'portal_read'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "portal_read" ON compliance_uploads
        FOR SELECT TO anon
        USING (organisation_id = '00000001-0000-0000-0000-000000000001')
    $policy$;
  END IF;
END $$;

-- ── 5. Allow anon SELECT on compliance_findings (for results) ──
ALTER TABLE compliance_findings ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'compliance_findings' AND policyname = 'portal_read'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "portal_read" ON compliance_findings
        FOR SELECT TO anon
        USING (
          upload_id IN (
            SELECT id FROM compliance_uploads 
            WHERE organisation_id = '00000001-0000-0000-0000-000000000001'
          )
        )
    $policy$;
  END IF;
END $$;

