-- Migration: 20260228215558_rls_lockdown_enforcement_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: rls_lockdown_enforcement_tables


-- ═══════════════════════════════════════════════════════════
-- RLS LOCKDOWN: Enable RLS & tighten INSERT policies
-- 
-- Principle: 
--   READ  → public (anon + authenticated)
--   WRITE → service_role only (backend scrapers)
--   
-- Affected: ehrc_enforcement_actions, hse_enforcement_notices,
--           ico_enforcement_actions, regulatory_updates, scraper_runs
-- ═══════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
-- 1. EHRC ENFORCEMENT ACTIONS
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.ehrc_enforcement_actions ENABLE ROW LEVEL SECURITY;

-- Drop open anon INSERT policies
DROP POLICY IF EXISTS "Scraper insert EHRC" ON public.ehrc_enforcement_actions;
DROP POLICY IF EXISTS "anon_insert_ehrc" ON public.ehrc_enforcement_actions;

-- Keep: "Public read EHRC" (SELECT for anon+authenticated) ✓
-- Keep: "service_insert_ehrc" (INSERT for service_role) ✓

-- ──────────────────────────────────────────────────────────
-- 2. HSE ENFORCEMENT NOTICES
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.hse_enforcement_notices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Scraper insert HSE" ON public.hse_enforcement_notices;
DROP POLICY IF EXISTS "anon_insert_hse" ON public.hse_enforcement_notices;

-- Keep: "Public read HSE" ✓
-- Keep: "service_insert_hse" ✓

-- ──────────────────────────────────────────────────────────
-- 3. ICO ENFORCEMENT ACTIONS
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.ico_enforcement_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Scraper insert ICO" ON public.ico_enforcement_actions;
DROP POLICY IF EXISTS "anon_insert_ico" ON public.ico_enforcement_actions;

-- Keep: "Public read ICO" ✓
-- Keep: "service_insert_ico" ✓

-- ──────────────────────────────────────────────────────────
-- 4. REGULATORY UPDATES
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.regulatory_updates ENABLE ROW LEVEL SECURITY;

-- Drop open anon INSERT
DROP POLICY IF EXISTS "Anon can insert regulatory updates" ON public.regulatory_updates;

-- Add public read for anon (currently only authenticated can read)
CREATE POLICY "Anon read regulatory updates"
  ON public.regulatory_updates FOR SELECT TO anon
  USING (true);

-- Keep: "Authenticated read regulatory updates" ✓
-- Keep: "Scraper can insert regulatory updates" (service_role) ✓

-- ──────────────────────────────────────────────────────────
-- 5. SCRAPER RUNS
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.scraper_runs ENABLE ROW LEVEL SECURITY;

-- Drop open anon INSERT and UPDATE
DROP POLICY IF EXISTS "Scraper can insert runs" ON public.scraper_runs;
DROP POLICY IF EXISTS "Scraper can update runs" ON public.scraper_runs;

-- Keep: "Authenticated read scraper runs" ✓
-- Keep: "service_role_insert_scraper_runs" ✓  
-- Keep: "service_role_update_scraper_runs" ✓

