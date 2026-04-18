-- Migration: 20260417222421_create_partner_api_infrastructure
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_partner_api_infrastructure


-- Partner API account management and request logging
CREATE TABLE IF NOT EXISTS public.api_partners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_name TEXT NOT NULL,
  partner_code TEXT NOT NULL UNIQUE,
  api_key_hash TEXT NOT NULL,
  api_key_prefix TEXT NOT NULL,
  hmac_secret_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','revoked','pending')),
  rate_limit_per_hour INTEGER DEFAULT 1000,
  batch_limit_per_hour INTEGER DEFAULT 100,
  allowed_endpoints TEXT[] DEFAULT ARRAY['profile','tribunal','regulatory','benchmark','alerts','batch'],
  employer_scope TEXT DEFAULT 'all' CHECK (employer_scope IN ('all','licensed','custom')),
  licensed_employer_ids UUID[],
  contract_start DATE,
  contract_end DATE,
  billing_model TEXT CHECK (billing_model IN ('flat','per_employer','revenue_share','hybrid')),
  billing_amount_annual_gbp NUMERIC(12,2),
  contact_email TEXT,
  contact_name TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.api_partners IS 'White-label API partner accounts. API keys stored as SHA-256 hashes only.';

CREATE TABLE IF NOT EXISTS public.api_request_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES public.api_partners(id),
  endpoint TEXT NOT NULL,
  method TEXT NOT NULL,
  employer_ch_number TEXT,
  canonical_employer_id UUID,
  response_status INTEGER,
  response_time_ms INTEGER,
  request_timestamp TIMESTAMPTZ DEFAULT NOW(),
  ip_address INET
);
CREATE INDEX IF NOT EXISTS idx_api_log_partner ON public.api_request_log(partner_id, request_timestamp);
CREATE INDEX IF NOT EXISTS idx_api_log_employer ON public.api_request_log(canonical_employer_id);
COMMENT ON TABLE public.api_request_log IS 'API request audit log for billing, rate limiting, and usage analytics.';

