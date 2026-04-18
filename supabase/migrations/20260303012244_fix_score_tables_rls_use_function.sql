-- Migration: 20260303012244_fix_score_tables_rls_use_function
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_score_tables_rls_use_function


-- Replace domain scores policy to use the safe function
DROP POLICY IF EXISTS "Authenticated read own org domain scores" ON acei_domain_scores;
CREATE POLICY "Authenticated read own org domain scores"
  ON acei_domain_scores
  FOR SELECT
  TO authenticated
  USING (org_id = public.get_my_org_id());

-- Replace category scores policy to use the safe function
DROP POLICY IF EXISTS "Authenticated read own org category scores" ON acei_category_scores;
CREATE POLICY "Authenticated read own org category scores"
  ON acei_category_scores
  FOR SELECT
  TO authenticated
  USING (org_id = public.get_my_org_id());

