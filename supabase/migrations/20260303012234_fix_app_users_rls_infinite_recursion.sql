-- Migration: 20260303012234_fix_app_users_rls_infinite_recursion
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_app_users_rls_infinite_recursion


-- DROP the recursive policy that causes infinite recursion
DROP POLICY IF EXISTS "app_users_select_same_org" ON app_users;

-- DROP the earlier fix attempt (redundant with new policy below)
DROP POLICY IF EXISTS "Users can read own record" ON app_users;

-- NEW: Users can read their own record (no self-reference)
CREATE POLICY "app_users_read_own"
  ON app_users
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- NEW: Users can see others in same org using a security definer function
-- to avoid the self-referential RLS problem
CREATE OR REPLACE FUNCTION public.get_my_org_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT org_id FROM app_users WHERE id = auth.uid()
$$;

CREATE POLICY "app_users_read_same_org"
  ON app_users
  FOR SELECT
  TO authenticated
  USING (org_id = public.get_my_org_id());

