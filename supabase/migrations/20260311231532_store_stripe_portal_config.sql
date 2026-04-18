-- Migration: 20260311231532_store_stripe_portal_config
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: store_stripe_portal_config


INSERT INTO platform_config (key, value, notes) VALUES
  ('stripe_portal_config_id', 'bpc_1T9vxoIHmra281v73TDY4FXc', 'Stripe Customer Portal configuration ID. Public portal URL to be stored as stripe_portal_url once activated.')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();

