-- Migration: 20260311014032_add_price_id_and_payment_link_to_stripe_products
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_price_id_and_payment_link_to_stripe_products


ALTER TABLE stripe_products
  ADD COLUMN IF NOT EXISTS price_id         TEXT,
  ADD COLUMN IF NOT EXISTS payment_link_url TEXT,
  ADD COLUMN IF NOT EXISTS portal_url       TEXT;

COMMENT ON COLUMN stripe_products.price_id         IS 'Stripe price_... ID — required for webhook matching and checkout sessions';
COMMENT ON COLUMN stripe_products.payment_link_url IS 'Stripe Payment Link URL — buy.stripe.com/... — for one-time scan products';
COMMENT ON COLUMN stripe_products.portal_url       IS 'Stripe Customer Portal URL — billing.stripe.com/p/login/... — stored on platform subscription rows only';

