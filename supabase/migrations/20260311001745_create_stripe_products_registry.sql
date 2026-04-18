-- Migration: 20260311001745_create_stripe_products_registry
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_stripe_products_registry


-- Stripe Products Registry
-- Single source of truth for all Stripe product IDs across the Ailane platform
-- Referenced by webhook handlers, checkout flows, and dashboard tier logic

CREATE TABLE IF NOT EXISTS stripe_products (
  id                  SERIAL PRIMARY KEY,
  product_id          TEXT NOT NULL UNIQUE,        -- Stripe prod_ ID
  product_type        TEXT NOT NULL UNIQUE,        -- Internal type key
  display_name        TEXT NOT NULL,               -- Human-readable name
  category            TEXT NOT NULL,               -- platform | compliance | kl
  billing_model       TEXT NOT NULL,               -- subscription | one_time | usage
  price_gbp           NUMERIC(10,2),               -- Base price in GBP (null = custom/free)
  is_active           BOOLEAN NOT NULL DEFAULT true,
  notes               TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Populate all 17 products
INSERT INTO stripe_products (product_id, product_type, display_name, category, billing_model, price_gbp, notes) VALUES

-- ── Core Platform Subscriptions ──────────────────────────────────────────────
('prod_U6M9TbvzD0djNO', 'operational',            'Ailane Operational',          'platform',    'subscription', 199.00,  'ACEI only. 1 user. 3 doc slots. Full UK KL. AILANE-SPEC-DASH-OPS-001 v1.1.'),
('prod_U6MEW9U3egjRUG', 'governance',             'Ailane Governance',           'platform',    'subscription', 799.00,  'Full Index Triad. 25 users. Unlimited docs. UK+EU KL. Clause-level remediation.'),

-- ── Compliance One-Time Scans ─────────────────────────────────────────────────
('prod_U5z0AacqsoZMZX', 'scan_anonymous',         'Ailane Flash Check',          'compliance',  'one_time',      19.00,  'Anonymous single ACEI scan. No account required.'),
('prod_U5z8tTvCdzIM4M', 'scan_report',            'Ailane Full Check',           'compliance',  'one_time',      39.00,  'Anonymous scan + full PDF compliance report. No account required.'),

-- ── Knowledge Library — Guest Tier ───────────────────────────────────────────
('prod_U7jBfSFo4kkTZp', 'kl_guest_discovery',    'KL Guest Discovery',          'kl',          'one_time',      NULL,   'Free discovery access to Knowledge Library.'),
('prod_U7jJhZxQGXGEpQ', 'kl_guest_day',          'KL Guest Day Pass',           'kl',          'one_time',      39.00,  'Single day guest access to KL.'),
('prod_U7jLzgiQyxFJcc', 'kl_guest_week',         'KL Guest Research Week',      'kl',          'one_time',      79.00,  'One week guest access to KL.'),

-- ── Knowledge Library — Pro Tier ─────────────────────────────────────────────
('prod_U7jMfQ14EPXjCd', 'kl_pro_mini',           'KL Pro Mini Session',         'kl',          'one_time',      49.00,  'Single pro session access to KL.'),
('prod_U7jNvKa1Z8geqa', 'kl_pro_day',            'KL Pro Day Pass',             'kl',          'one_time',     119.00,  'Single day pro access to KL.'),
('prod_U7jP7QXknxPMnZ', 'kl_pro_week',           'KL Pro Research Week',        'kl',          'one_time',     149.00,  'One week pro access to KL.'),
('prod_U7jYR4YneHYfLe', 'kl_monthly',            'KL Professional Monthly',     'kl',          'subscription', 249.00,  'Monthly recurring KL professional subscription.'),

-- ── Knowledge Library — Reports & Add-Ons ────────────────────────────────────
('prod_U7jpCyZEQhGe75', 'kl_report_transcript_guest', 'KL Chat Transcript — Guest', 'kl',     'one_time',       5.00,  'Guest chat transcript download.'),
('prod_U7jqxOGypPFfiG', 'kl_report_transcript_pro',  'KL Chat Transcript — Pro',   'kl',     'one_time',      10.00,  'Pro chat transcript download.'),
('prod_U7jrQPuy1UJVRW', 'kl_report_advisory',    'KL Session Advisory Add-On',  'kl',          'one_time',      45.00,  'Advisory add-on for a KL session.'),
('prod_U7jtpWLBpkejQ6', 'kl_report_project',     'KL Project Summary Add-On',   'kl',          'one_time',      99.00,  'Project summary report add-on.'),
('prod_U7jtFh0Sc10gKl', 'kl_post_allowance',     'KL Post Advisory',            'kl',          'one_time',      35.00,  'Post-session advisory allowance.'),
('prod_U7k0XC0U8tDF2u', 'kl_report_project_overage', 'KL Overage Project Summary', 'kl',     'one_time',      NULL,   'Overage charge for additional project summaries.');

-- Index for fast lookups by product_type (used in webhook handler)
CREATE INDEX IF NOT EXISTS idx_stripe_products_type ON stripe_products(product_type);
CREATE INDEX IF NOT EXISTS idx_stripe_products_active ON stripe_products(is_active);

