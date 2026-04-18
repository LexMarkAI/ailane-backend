-- Migration: 20260302154042_rls_hardening_march_2026
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: rls_hardening_march_2026


-- =============================================================================
-- RLS HARDENING MIGRATION — March 2, 2026
-- Constitutional Compliance: ACEI v1.0 Art. IX (Data Integrity & Access)
-- Purpose: Org-scope all client data, harden WITH CHECK clauses
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. HIGH PRIORITY: Org-scope ACEI score tables
-- ─────────────────────────────────────────────────────────────────────────────

-- 1a. acei_category_scores: Replace open SELECT with org-scoped
DROP POLICY IF EXISTS "Public read category scores" ON acei_category_scores;

CREATE POLICY "Authenticated read own org category scores"
ON acei_category_scores FOR SELECT
TO authenticated
USING (
    org_id IN (
        SELECT app_users.org_id 
        FROM app_users 
        WHERE app_users.id = auth.uid()
    )
);

-- Service role write (scoring engine)
CREATE POLICY "Service role manage category scores"
ON acei_category_scores FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- 1b. acei_domain_scores: Replace open SELECT with org-scoped
DROP POLICY IF EXISTS "Public read domain scores" ON acei_domain_scores;

CREATE POLICY "Authenticated read own org domain scores"
ON acei_domain_scores FOR SELECT
TO authenticated
USING (
    org_id IN (
        SELECT app_users.org_id 
        FROM app_users 
        WHERE app_users.id = auth.uid()
    )
);

-- Service role write (scoring engine)
CREATE POLICY "Service role manage domain scores"
ON acei_domain_scores FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. MEDIUM: Fix org_actions UPDATE — add WITH CHECK to prevent org_id mutation
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Users manage own org actions" ON org_actions;

CREATE POLICY "Users update own org actions"
ON org_actions FOR UPDATE
TO authenticated
USING (
    org_id IN (
        SELECT app_users.org_id 
        FROM app_users 
        WHERE app_users.email = (auth.jwt() ->> 'email')
    )
)
WITH CHECK (
    org_id IN (
        SELECT app_users.org_id 
        FROM app_users 
        WHERE app_users.email = (auth.jwt() ->> 'email')
    )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. MEDIUM: Harden event_summaries — proper role scoping + WITH CHECK
-- ─────────────────────────────────────────────────────────────────────────────

-- Drop existing loose policies
DROP POLICY IF EXISTS "Authenticated users can insert event summaries" ON event_summaries;
DROP POLICY IF EXISTS "Authenticated users can update event summaries" ON event_summaries;
DROP POLICY IF EXISTS "Service role full access to event summaries" ON event_summaries;
DROP POLICY IF EXISTS "Public read access to event summaries" ON event_summaries;

-- Rebuild with correct role scoping
CREATE POLICY "Authenticated read event summaries"
ON event_summaries FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Authenticated insert event summaries"
ON event_summaries FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Authenticated update event summaries"
ON event_summaries FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Service role full access event summaries"
ON event_summaries FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. MEDIUM: Fix org_jurisdictions — tighten role from {public} to proper roles
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "org_jur_select_own" ON org_jurisdictions;
DROP POLICY IF EXISTS "org_jur_service_all" ON org_jurisdictions;

CREATE POLICY "Authenticated read own org jurisdictions"
ON org_jurisdictions FOR SELECT
TO authenticated
USING (
    org_id IN (
        SELECT app_users.org_id 
        FROM app_users 
        WHERE app_users.id = auth.uid()
    )
);

CREATE POLICY "Service role manage org jurisdictions"
ON org_jurisdictions FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

