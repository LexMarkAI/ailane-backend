-- Migration: 20260315012421_create_company_event_register
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_company_event_register


-- Company Event Register (CER)
-- Institutional memory for business-critical events.
-- Every event becomes a training signal for AI-augmented operations.
-- Only business-critical events are logged here — not noise.

CREATE TABLE public.company_event_register (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Classification
  event_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ,
  duration_minutes INTEGER GENERATED ALWAYS AS (
    CASE WHEN resolved_at IS NOT NULL 
      THEN EXTRACT(EPOCH FROM (resolved_at - event_date))::integer / 60 
      ELSE NULL 
    END
  ) STORED,
  
  severity TEXT NOT NULL CHECK (severity IN ('critical', 'major', 'minor', 'informational')),
  category TEXT NOT NULL CHECK (category IN (
    'system_outage', 'payment_failure', 'data_pipeline', 'auth_failure',
    'webhook_failure', 'scraper_failure', 'deployment_issue', 'security_event',
    'regulatory_event', 'legal_event', 'financial_event', 'product_change',
    'infrastructure_change', 'vendor_event', 'milestone'
  )),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'monitoring')),
  
  -- What happened
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  affected_systems TEXT[] DEFAULT '{}',
  business_impact TEXT,
  
  -- Root cause & resolution
  root_cause TEXT,
  resolution_steps TEXT,
  resolution_type TEXT CHECK (resolution_type IN ('ai_autonomous', 'ai_guided', 'human_manual', 'vendor_action', 'self_resolved', 'pending')),
  
  -- AI autonomy assessment
  human_intervention_required BOOLEAN,
  ai_could_have_resolved BOOLEAN,
  ai_confidence_note TEXT,
  
  -- Forward learning
  prevention_measures TEXT,
  pattern_id TEXT,
  related_event_ids UUID[] DEFAULT '{}',
  
  -- Metadata
  reported_by TEXT DEFAULT 'system',
  tags TEXT[] DEFAULT '{}',
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Comment
COMMENT ON TABLE public.company_event_register IS 
  'CER: Institutional memory for business-critical events. Every event is a training signal for AI-augmented operations. Tracks resolution type, human intervention requirement, and AI autonomy assessment. Investor-visible operational maturity metric.';

-- Index for timeline queries
CREATE INDEX idx_cer_event_date ON public.company_event_register(event_date DESC);
CREATE INDEX idx_cer_severity ON public.company_event_register(severity);
CREATE INDEX idx_cer_status ON public.company_event_register(status);
CREATE INDEX idx_cer_category ON public.company_event_register(category);

-- RLS
ALTER TABLE public.company_event_register ENABLE ROW LEVEL SECURITY;

-- CEO read/write
CREATE POLICY "CEO full access to CER" ON public.company_event_register
  FOR ALL USING (
    auth.jwt() ->> 'email' = 'mark@ailane.ai'
  );

-- Service role full access (for Edge Functions)
CREATE POLICY "Service role CER access" ON public.company_event_register
  FOR ALL USING (
    auth.role() = 'service_role'
  );

-- Credentials lifecycle tracker
CREATE TABLE public.credentials_lifecycle (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  credential_name TEXT NOT NULL,
  provider TEXT NOT NULL,
  credential_type TEXT NOT NULL CHECK (credential_type IN (
    'api_key', 'webhook_secret', 'oauth_token', 'ssl_cert', 
    'domain_registration', 'subscription', 'registration', 'trademark'
  )),
  
  -- Lifecycle dates
  issued_date DATE,
  expiry_date DATE,
  last_rotated DATE,
  next_review_date DATE,
  
  -- Status
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expiring_soon', 'expired', 'rotated', 'decommissioned')),
  auto_renews BOOLEAN DEFAULT false,
  
  -- Location
  stored_in TEXT NOT NULL,
  rotation_procedure TEXT,
  
  -- Business impact if expired
  impact_if_expired TEXT NOT NULL,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.credentials_lifecycle IS 
  'Tracks all API keys, secrets, certificates, registrations, and subscriptions with expiry dates and rotation status. Prevents silent system failures from expired credentials.';

ALTER TABLE public.credentials_lifecycle ENABLE ROW LEVEL SECURITY;

CREATE POLICY "CEO credentials access" ON public.credentials_lifecycle
  FOR ALL USING (auth.jwt() ->> 'email' = 'mark@ailane.ai');

CREATE POLICY "Service role credentials access" ON public.credentials_lifecycle
  FOR ALL USING (auth.role() = 'service_role');

CREATE INDEX idx_creds_expiry ON public.credentials_lifecycle(expiry_date);
CREATE INDEX idx_creds_status ON public.credentials_lifecycle(status);

