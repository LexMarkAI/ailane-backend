-- Migration: 20260307134622_rls_lockdown_remaining_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: rls_lockdown_remaining_tables


-- ═══════════════════════════════════════════════════════════════════════════
-- AILANE MIGRATION: RLS lockdown — remaining tables
-- Date: 2026-03-07
-- Tables: legislation_fulltext, supported_languages,
--         pcie_cci_conduct_events, pcie_cci_scores, pcie_rri_pillars
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. legislation_fulltext ───────────────────────────────────────────────
-- Full statutory text is ALWAYS accessed via get_fulltext_for_org() RPC
-- (SECURITY DEFINER — enforces tier and language gates).
-- Direct table access is DENIED to all non-service-role principals.
-- This prevents tier circumvention via direct REST API calls.

ALTER TABLE legislation_fulltext ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_full_fulltext"
  ON legislation_fulltext
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- No anon or authenticated policy — use get_fulltext_for_org() RPC only.
-- Attempts to SELECT directly will return zero rows for anon/auth.


-- ── 2. supported_languages ────────────────────────────────────────────────
-- Public reference data — language registry.
-- Readable by everyone. Writable only by service_role.

ALTER TABLE supported_languages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_read_supported_languages"
  ON supported_languages
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "service_role_full_supported_languages"
  ON supported_languages
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);


-- ── 3. pcie_cci_conduct_events ────────────────────────────────────────────
-- Constitutional CCI conduct event ledger.
-- Strict separation doctrine: each org sees only its own events.
-- Demonstration data visible to authenticated users only.

CREATE POLICY "org_read_own_cci_events"
  ON pcie_cci_conduct_events
  FOR SELECT
  TO authenticated
  USING (
    org_id = get_my_org_id()
    OR is_demonstration_data = TRUE
  );

CREATE POLICY "service_role_full_cci_events"
  ON pcie_cci_conduct_events
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);


-- ── 4. pcie_cci_scores ────────────────────────────────────────────────────
-- CCI weekly score snapshots.
-- Strict separation: org sees only own scores.
-- Demonstration scores visible to authenticated users for benchmarking.

CREATE POLICY "org_read_own_cci_scores"
  ON pcie_cci_scores
  FOR SELECT
  TO authenticated
  USING (
    org_id = get_my_org_id()
    OR is_demonstration_data = TRUE
  );

CREATE POLICY "service_role_full_cci_scores"
  ON pcie_cci_scores
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);


-- ── 5. pcie_rri_pillars ───────────────────────────────────────────────────
-- RRI 5-pillar computed results.
-- Constitutional strict separation: org sees only own pillar data.
-- Demonstration data visible for benchmarking comparisons.

CREATE POLICY "org_read_own_rri_pillars"
  ON pcie_rri_pillars
  FOR SELECT
  TO authenticated
  USING (
    org_id = get_my_org_id()
    OR is_demonstration_data = TRUE
  );

CREATE POLICY "service_role_full_rri_pillars"
  ON pcie_rri_pillars
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);


-- ── VERIFICATION ──────────────────────────────────────────────────────────
-- Confirm no table in public schema has rls_enabled = false
-- (run manually after migration if needed):
-- SELECT tablename, rowsecurity FROM pg_tables
-- WHERE schemaname = 'public' AND rowsecurity = false;

