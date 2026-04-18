-- Migration: 20260227013457_enable_rls_all_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: enable_rls_all_tables


-- ============================================================
-- RLS LOCKDOWN: Enable RLS on all 19 unprotected public tables
-- Policy strategy:
--   PUBLIC READ: anon + authenticated can SELECT (dashboard data)
--   SCRAPER WRITE: anon can INSERT (tribunal_decisions, scraper_runs)
--   ORG-SCOPED: authenticated users see own org data only
--   SYSTEM ONLY: no anon/authenticated access (admin via service_role)
-- ============================================================

-- ==========================================
-- 1. PUBLIC READ + SCRAPER WRITE TABLES
-- ==========================================

-- tribunal_decisions: public read, scraper inserts via anon key
ALTER TABLE tribunal_decisions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read tribunal decisions" ON tribunal_decisions
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Scraper can insert tribunal decisions" ON tribunal_decisions
  FOR INSERT TO anon WITH CHECK (true);

-- scraper_runs: scraper logs via anon key
ALTER TABLE scraper_runs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Scraper can insert runs" ON scraper_runs
  FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Scraper can update runs" ON scraper_runs
  FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated read scraper runs" ON scraper_runs
  FOR SELECT TO authenticated USING (true);

-- ==========================================
-- 2. PUBLIC READ-ONLY TABLES (dashboard data)
-- ==========================================

-- acei_versions: index version metadata
ALTER TABLE acei_versions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read acei versions" ON acei_versions
  FOR SELECT TO anon, authenticated USING (true);

-- acei_domain_scores: feeds dashboard gauge
ALTER TABLE acei_domain_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read domain scores" ON acei_domain_scores
  FOR SELECT TO anon, authenticated USING (true);

-- acei_category_scores: feeds dashboard category grid
ALTER TABLE acei_category_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read category scores" ON acei_category_scores
  FOR SELECT TO anon, authenticated USING (true);

-- ==========================================
-- 3. REFERENCE TABLES (authenticated read)
-- ==========================================

-- sources
ALTER TABLE sources ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated read sources" ON sources
  FOR SELECT TO authenticated USING (true);

-- regulations
ALTER TABLE regulations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated read regulations" ON regulations
  FOR SELECT TO authenticated USING (true);

-- regulation_updates
ALTER TABLE regulation_updates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated read regulation updates" ON regulation_updates
  FOR SELECT TO authenticated USING (true);

-- actions
ALTER TABLE actions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated read actions" ON actions
  FOR SELECT TO authenticated USING (true);

-- events
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated read events" ON events
  FOR SELECT TO authenticated USING (true);

-- ==========================================
-- 4. ORG-SCOPED TABLES (users see own org)
-- ==========================================

-- organisations: users see their own org
ALTER TABLE organisations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own organisation" ON organisations
  FOR SELECT TO authenticated
  USING (id IN (SELECT org_id FROM app_users WHERE email = auth.jwt()->>'email'));

-- org_actions: scoped to user's org
ALTER TABLE org_actions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own org actions" ON org_actions
  FOR SELECT TO authenticated
  USING (org_id IN (SELECT org_id FROM app_users WHERE email = auth.jwt()->>'email'));
CREATE POLICY "Users manage own org actions" ON org_actions
  FOR UPDATE TO authenticated
  USING (org_id IN (SELECT org_id FROM app_users WHERE email = auth.jwt()->>'email'));

-- evidence: scoped to user's org via org_actions
ALTER TABLE evidence ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own org evidence" ON evidence
  FOR SELECT TO authenticated
  USING (org_action_id IN (
    SELECT id FROM org_actions WHERE org_id IN (
      SELECT org_id FROM app_users WHERE email = auth.jwt()->>'email'
    )
  ));

-- audit_events: scoped to user's org
ALTER TABLE audit_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own org audit events" ON audit_events
  FOR SELECT TO authenticated
  USING (org_id IN (SELECT org_id FROM app_users WHERE email = auth.jwt()->>'email'));

-- mitigation_register: scoped to user's org
ALTER TABLE mitigation_register ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own org mitigations" ON mitigation_register
  FOR SELECT TO authenticated
  USING (org_id IN (SELECT org_id FROM app_users WHERE email = auth.jwt()->>'email'));
CREATE POLICY "Users manage own org mitigations" ON mitigation_register
  FOR INSERT TO authenticated
  WITH CHECK (org_id IN (SELECT org_id FROM app_users WHERE email = auth.jwt()->>'email'));

-- ==========================================
-- 5. SYSTEM-ONLY TABLES (service_role access)
-- No policies = only service_role can access
-- ==========================================

ALTER TABLE data_quality_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE unclassified_register ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE decision_versions ENABLE ROW LEVEL SECURITY;
