-- Migration: 20260311231617_store_stripe_portal_url
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: store_stripe_portal_url


INSERT INTO platform_config (key, value, notes) VALUES
  ('stripe_portal_url', 'https://billing.stripe.com/p/login/cNibJ26rmfwmgcb5hlfMA00', 'Stripe Customer Portal public URL. Embed in account/dashboard/index.html P-OPS-13 Account Management panel.')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();

UPDATE stripe_products 
SET portal_url = 'https://billing.stripe.com/p/login/cNibJ26rmfwmgcb5hlfMA00'
WHERE product_type IN ('operational', 'governance');

