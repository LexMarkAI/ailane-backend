-- Migration: 20260302193832_aie_employer_master_rls_enrichment
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: aie_employer_master_rls_enrichment


-- Enable RLS on employer_master if not already enabled
ALTER TABLE employer_master ENABLE ROW LEVEL SECURITY;

-- Allow anon role to read employer_master (for enrichment queries)
CREATE POLICY "anon_read_employer_master" ON employer_master
  FOR SELECT TO anon USING (true);

-- Allow anon role to update employer_master (for enrichment writes)
CREATE POLICY "anon_update_employer_master" ON employer_master
  FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- Same for the service_role (already bypasses RLS, but belt and braces)
CREATE POLICY "service_read_employer_master" ON employer_master
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "service_update_employer_master" ON employer_master
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

