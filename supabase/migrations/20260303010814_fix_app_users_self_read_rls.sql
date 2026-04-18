-- Migration: 20260303010814_fix_app_users_self_read_rls
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_app_users_self_read_rls


-- Add a direct self-read policy so users can always read their own row
-- This breaks the circular dependency: domain_scores -> app_users -> app_users
CREATE POLICY "Users can read own record"
  ON app_users
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

