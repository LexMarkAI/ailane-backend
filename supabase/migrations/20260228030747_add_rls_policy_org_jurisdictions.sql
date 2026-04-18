-- Migration: 20260228030747_add_rls_policy_org_jurisdictions
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_rls_policy_org_jurisdictions


-- RLS for org_jurisdictions: authenticated users see their own org's jurisdictions
CREATE POLICY "org_jur_select_own" ON org_jurisdictions
  FOR SELECT USING (
    org_id IN (
      SELECT org_id FROM app_users WHERE id = auth.uid()
    )
  );

-- Service role can manage all
CREATE POLICY "org_jur_service_all" ON org_jurisdictions
  FOR ALL USING (auth.role() = 'service_role');

