-- Migration: 20260314211051_add_accounts_transactions_to_realtime_publication
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_accounts_transactions_to_realtime_publication


-- Add accounts.transactions to Supabase Realtime publication
-- Enables live WebSocket push of new Monzo transactions to CEO dashboard
ALTER PUBLICATION supabase_realtime ADD TABLE accounts.transactions;

