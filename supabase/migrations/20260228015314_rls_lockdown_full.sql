-- Migration: 20260228015314_rls_lockdown_full
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: rls_lockdown_full


-- ================================================================
-- AILANE RLS LOCKDOWN — Full Security Hardening
-- Date: 2026-02-28
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- 1. FIX ZERO-POLICY TABLES
-- ────────────────────────────────────────────────────────────────

-- audit_log: authenticated users read own entries (scoped by user_id)
CREATE POLICY "Users read own audit_log"
  ON public.audit_log FOR SELECT TO authenticated
  USING (user_id = auth.uid()::text);

-- data_quality_issues: authenticated read-only (operational)
CREATE POLICY "Authenticated read data_quality_issues"
  ON public.data_quality_issues FOR SELECT TO authenticated
  USING (true);

-- decision_versions: public read (reference data, no sensitive content)
CREATE POLICY "Public read decision_versions"
  ON public.decision_versions FOR SELECT TO anon, authenticated
  USING (true);

-- unclassified_register: authenticated read-only
CREATE POLICY "Authenticated read unclassified_register"
  ON public.unclassified_register FOR SELECT TO authenticated
  USING (true);

-- ────────────────────────────────────────────────────────────────
-- 2. CLOSE ANON EMAIL LEAK ON SIGNUPS
-- ────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "anon_select_signups" ON public.early_access_signups;

-- ────────────────────────────────────────────────────────────────
-- 3. ADD MISSING WRITE POLICIES FOR CLIENT TABLES
-- ────────────────────────────────────────────────────────────────

-- evidence: org-scoped INSERT
CREATE POLICY "Users insert own org evidence"
  ON public.evidence FOR INSERT TO authenticated
  WITH CHECK (
    org_action_id IN (
      SELECT id FROM org_actions
      WHERE org_id IN (
        SELECT org_id FROM app_users 
        WHERE email = (auth.jwt() ->> 'email')
      )
    )
  );

-- evidence: org-scoped DELETE
CREATE POLICY "Users delete own org evidence"
  ON public.evidence FOR DELETE TO authenticated
  USING (
    org_action_id IN (
      SELECT id FROM org_actions
      WHERE org_id IN (
        SELECT org_id FROM app_users 
        WHERE email = (auth.jwt() ->> 'email')
      )
    )
  );

-- audit_events: org-scoped INSERT
CREATE POLICY "Users insert own org audit_events"
  ON public.audit_events FOR INSERT TO authenticated
  WITH CHECK (
    org_id IN (
      SELECT org_id FROM app_users 
      WHERE email = (auth.jwt() ->> 'email')
    )
  );

-- mitigation_register: org-scoped UPDATE
CREATE POLICY "Users update own org mitigations"
  ON public.mitigation_register FOR UPDATE TO authenticated
  USING (
    org_id IN (
      SELECT org_id FROM app_users 
      WHERE email = (auth.jwt() ->> 'email')
    )
  )
  WITH CHECK (
    org_id IN (
      SELECT org_id FROM app_users 
      WHERE email = (auth.jwt() ->> 'email')
    )
  );

-- mitigation_register: org-scoped DELETE
CREATE POLICY "Users delete own org mitigations"
  ON public.mitigation_register FOR DELETE TO authenticated
  USING (
    org_id IN (
      SELECT org_id FROM app_users 
      WHERE email = (auth.jwt() ->> 'email')
    )
  );

-- org_actions: org-scoped INSERT
CREATE POLICY "Users insert own org actions"
  ON public.org_actions FOR INSERT TO authenticated
  WITH CHECK (
    org_id IN (
      SELECT org_id FROM app_users 
      WHERE email = (auth.jwt() ->> 'email')
    )
  );

-- org_actions: org-scoped DELETE
CREATE POLICY "Users delete own org actions"
  ON public.org_actions FOR DELETE TO authenticated
  USING (
    org_id IN (
      SELECT org_id FROM app_users 
      WHERE email = (auth.jwt() ->> 'email')
    )
  );
