-- Migration: 20260311012252_fix_kl_discovery_and_overage_prices
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_kl_discovery_and_overage_prices


UPDATE stripe_products SET price_gbp = 19.00 WHERE product_type = 'kl_guest_discovery';
UPDATE stripe_products SET price_gbp = 75.00 WHERE product_type = 'kl_report_project_overage';

