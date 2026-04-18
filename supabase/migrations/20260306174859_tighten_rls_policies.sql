-- Migration: 20260306174859_tighten_rls_policies
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: tighten_rls_policies


-- 1. compliance_portal_sessions: portal_insert — require valid stripe_session_id
DROP POLICY IF EXISTS portal_insert ON public.compliance_portal_sessions;
CREATE POLICY portal_insert ON public.compliance_portal_sessions
  FOR INSERT TO anon
  WITH CHECK (stripe_session_id IS NOT NULL AND length(trim(stripe_session_id)) > 0);

-- 2. compliance_portal_sessions: service_update — Edge Functions use service role key,
-- this policy covers the authenticated role as a scoped fallback (no further restriction
-- possible without a user-linked FK on this table)
DROP POLICY IF EXISTS service_update ON public.compliance_portal_sessions;
CREATE POLICY service_update ON public.compliance_portal_sessions
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

-- 3. early_access_signups: require valid email format
DROP POLICY IF EXISTS anon_insert_signups ON public.early_access_signups;
CREATE POLICY anon_insert_signups ON public.early_access_signups
  FOR INSERT TO anon
  WITH CHECK (email IS NOT NULL AND email LIKE '%@%.%');

-- 4. event_summaries: insert — restrict to non-null source_id (system writes only via service key)
DROP POLICY IF EXISTS "Authenticated insert event summaries" ON public.event_summaries;
CREATE POLICY "Authenticated insert event summaries" ON public.event_summaries
  FOR INSERT TO authenticated
  WITH CHECK (source_id IS NOT NULL);

-- 5. event_summaries: update — restrict to existing rows with a valid source
DROP POLICY IF EXISTS "Authenticated update event summaries" ON public.event_summaries;
CREATE POLICY "Authenticated update event summaries" ON public.event_summaries
  FOR UPDATE TO authenticated
  USING (source_id IS NOT NULL)
  WITH CHECK (source_id IS NOT NULL);

