-- Migration: 20260311230740_create_platform_config_and_store_webhook_url
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_platform_config_and_store_webhook_url


CREATE TABLE IF NOT EXISTS platform_config (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL,
  notes       TEXT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO platform_config (key, value, notes) VALUES
  ('stripe_webhook_endpoint', 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/stripe-webhook', 'Stripe webhook handler — Supabase Edge Function. Signing secret stored in Edge Function secrets as STRIPE_WEBHOOK_SECRET.')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();

