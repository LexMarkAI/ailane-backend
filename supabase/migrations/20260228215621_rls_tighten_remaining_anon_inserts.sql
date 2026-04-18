-- Migration: 20260228215621_rls_tighten_remaining_anon_inserts
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: rls_tighten_remaining_anon_inserts


-- ═══════════════════════════════════════════════════════════
-- TIGHTEN REMAINING ANON INSERT POLICIES
-- Convert scraper writes from anon → service_role only
-- 
-- Note: early_access_signups intentionally left open for
-- the ailane.ai landing page signup form.
-- ═══════════════════════════════════════════════════════════

-- 1. TRIBUNAL DECISIONS — most critical table
DROP POLICY IF EXISTS "Scraper can insert tribunal decisions" ON public.tribunal_decisions;
CREATE POLICY "Service role insert tribunal decisions"
  ON public.tribunal_decisions FOR INSERT TO service_role
  WITH CHECK (true);

-- Also need service_role UPDATE for the enrichment scraper
CREATE POLICY "Service role update tribunal decisions"
  ON public.tribunal_decisions FOR UPDATE TO service_role
  USING (true) WITH CHECK (true);

-- 2. HMCTS TRIBUNAL STATISTICS
DROP POLICY IF EXISTS "Scraper insert HMCTS" ON public.hmcts_tribunal_statistics;
CREATE POLICY "Service role insert HMCTS"
  ON public.hmcts_tribunal_statistics FOR INSERT TO service_role
  WITH CHECK (true);

-- 3. LEGISLATIVE CHANGES
DROP POLICY IF EXISTS "Scraper insert legislation" ON public.legislative_changes;
CREATE POLICY "Service role insert legislation"
  ON public.legislative_changes FOR INSERT TO service_role
  WITH CHECK (true);

