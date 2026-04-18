-- Migration: 20260303180917_rls_lockdown_remove_anon_write_policies
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: rls_lockdown_remove_anon_write_policies


-- ============================================================
-- AILANE RLS LOCKDOWN — MIGRATION 1 OF 3
-- Remove overly permissive anon WRITE policies
-- Fix misassigned service_role policies (on authenticated)
-- Tighten reference table and CEO table write access
-- Constitutional basis: institutional-grade security architecture
-- ============================================================

-- ── 1. ceo_daily_briefs ─────────────────────────────────────
-- Remove anon write access
DROP POLICY IF EXISTS "anon_insert_briefs" ON ceo_daily_briefs;
DROP POLICY IF EXISTS "anon_update_briefs" ON ceo_daily_briefs;
-- Replace wide-open authenticated ALL with service_role only writes
DROP POLICY IF EXISTS "auth_all_briefs" ON ceo_daily_briefs;
CREATE POLICY "service_role_all_briefs" ON ceo_daily_briefs
  FOR ALL TO service_role USING (true) WITH CHECK (true);
-- Keep anon read (CEO dashboard uses anon key for reads)

-- ── 2. ceo_reports ──────────────────────────────────────────
DROP POLICY IF EXISTS "anon_insert_reports" ON ceo_reports;
DROP POLICY IF EXISTS "auth_all_reports" ON ceo_reports;
CREATE POLICY "service_role_all_reports" ON ceo_reports
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── 3. company_documents ────────────────────────────────────
DROP POLICY IF EXISTS "anon_insert_docs" ON company_documents;
DROP POLICY IF EXISTS "anon_update_docs" ON company_documents;
DROP POLICY IF EXISTS "auth_all_docs" ON company_documents;
CREATE POLICY "service_role_all_docs" ON company_documents
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── 4. employer_master ──────────────────────────────────────
-- Remove anon update (was added as temporary workaround)
DROP POLICY IF EXISTS "anon_update_employer_master" ON employer_master;
-- Fix misnamed policies: "service_*" was on authenticated, move to service_role
DROP POLICY IF EXISTS "service_update_employer_master" ON employer_master;
CREATE POLICY "service_role_update_employer_master" ON employer_master
  FOR UPDATE TO service_role USING (true) WITH CHECK (true);
-- Add service_role INSERT (scrapers/enrichment need this)
CREATE POLICY "service_role_insert_employer_master" ON employer_master
  FOR INSERT TO service_role WITH CHECK (true);

-- ── 5. acei_scores ──────────────────────────────────────────
DROP POLICY IF EXISTS "anon_insert_acei_scores" ON acei_scores;
-- Fix: "service_all_acei_scores" was on authenticated, move to service_role
DROP POLICY IF EXISTS "service_all_acei_scores" ON acei_scores;
CREATE POLICY "service_role_all_acei_scores" ON acei_scores
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── 6. legislation_library ──────────────────────────────────
DROP POLICY IF EXISTS "anon_insert_legislation" ON legislation_library;
DROP POLICY IF EXISTS "anon_update_legislation" ON legislation_library;
-- Fix: "service_all_legislation" was on authenticated, move to service_role
DROP POLICY IF EXISTS "service_all_legislation" ON legislation_library;
CREATE POLICY "service_role_all_legislation" ON legislation_library
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── 7. legislation_amendments ───────────────────────────────
DROP POLICY IF EXISTS "anon_insert_amendments" ON legislation_amendments;
-- Add service_role write
CREATE POLICY "service_role_all_amendments" ON legislation_amendments
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── 8. alerts ───────────────────────────────────────────────
DROP POLICY IF EXISTS "anon_insert_alerts" ON alerts;
CREATE POLICY "service_role_all_alerts" ON alerts
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── 9. regulatory_events ────────────────────────────────────
DROP POLICY IF EXISTS "anon_insert_regulatory_events" ON regulatory_events;
-- Fix: "service_all_regulatory_events" was on authenticated, move to service_role
DROP POLICY IF EXISTS "service_all_regulatory_events" ON regulatory_events;
CREATE POLICY "service_role_all_regulatory_events" ON regulatory_events
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── 10. forward_exposure_register ───────────────────────────
DROP POLICY IF EXISTS "anon_insert_forward" ON forward_exposure_register;
CREATE POLICY "service_role_all_forward" ON forward_exposure_register
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── 11. Reference tables: restrict authenticated to READ-ONLY ──
-- acei_jurisdiction_map
DROP POLICY IF EXISTS "auth_all_jm" ON acei_jurisdiction_map;
CREATE POLICY "auth_read_jm" ON acei_jurisdiction_map
  FOR SELECT TO authenticated USING (true);

-- acei_sector_sic_map
DROP POLICY IF EXISTS "auth_all_sector_map" ON acei_sector_sic_map;
CREATE POLICY "auth_read_sector_map" ON acei_sector_sic_map
  FOR SELECT TO authenticated USING (true);

-- acei_subregion_postcode_map
DROP POLICY IF EXISTS "auth_all_subregion" ON acei_subregion_postcode_map;
CREATE POLICY "auth_read_subregion" ON acei_subregion_postcode_map
  FOR SELECT TO authenticated USING (true);

