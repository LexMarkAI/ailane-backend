-- Migration: 20260227013515_fix_security_advisors
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_security_advisors


-- Fix 1: Add missing policy for regulatory_updates
CREATE POLICY "Authenticated read regulatory updates" ON regulatory_updates
  FOR SELECT TO authenticated USING (true);

-- Fix 2: Fix security definer view
ALTER VIEW v_overdue_classifications SET (security_invoker = on);

-- Fix 3: Fix mutable search_path on functions
ALTER FUNCTION prevent_audit_log_modification() SET search_path = public;
ALTER FUNCTION set_review_deadline() SET search_path = public;
ALTER FUNCTION check_review_deadlines() SET search_path = public;
ALTER FUNCTION set_updated_at() SET search_path = public;
