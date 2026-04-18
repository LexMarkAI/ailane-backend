-- Migration: 20260303120328_rls_lockdown_remaining_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: rls_lockdown_remaining_tables


-- ============================================================================
-- RLS Lockdown: 5 remaining unprotected tables
-- Security advisor flagged these as ERROR level
-- ============================================================================

-- 1. employer_tribunal_profile
ALTER TABLE employer_tribunal_profile ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_read_etp ON employer_tribunal_profile FOR SELECT TO anon USING (true);
CREATE POLICY service_all_etp ON employer_tribunal_profile FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 2. employer_decision_link
ALTER TABLE employer_decision_link ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_read_edl ON employer_decision_link FOR SELECT TO anon USING (true);
CREATE POLICY service_all_edl ON employer_decision_link FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 3. campaign_prospects
ALTER TABLE campaign_prospects ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_read_cp ON campaign_prospects FOR SELECT TO anon USING (true);
CREATE POLICY service_all_cp ON campaign_prospects FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 4. employer_name_aliases
ALTER TABLE employer_name_aliases ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_read_ena ON employer_name_aliases FOR SELECT TO anon USING (true);
CREATE POLICY service_all_ena ON employer_name_aliases FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 5. aps_computation_log
ALTER TABLE aps_computation_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_read_acl ON aps_computation_log FOR SELECT TO anon USING (true);
CREATE POLICY service_all_acl ON aps_computation_log FOR ALL TO service_role USING (true) WITH CHECK (true);

