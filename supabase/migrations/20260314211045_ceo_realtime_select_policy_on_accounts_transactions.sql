-- Migration: 20260314211045_ceo_realtime_select_policy_on_accounts_transactions
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: ceo_realtime_select_policy_on_accounts_transactions


-- CEO-only read access on accounts.transactions for Realtime subscription
-- Scoped to mark@ailane.ai SELECT only — no other user, no write access
CREATE POLICY "ceo_select_transactions"
ON accounts.transactions
FOR SELECT
TO authenticated
USING (
  auth.jwt() ->> 'email' = 'mark@ailane.ai'
);

