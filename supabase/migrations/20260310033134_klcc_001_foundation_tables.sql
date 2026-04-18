-- Migration: 20260310033134_klcc_001_foundation_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: klcc_001_foundation_tables


-- ============================================================
-- KLCC-001 FOUNDATION TABLES
-- Prerequisites for KLAC-001 schema
-- ============================================================

-- kl_sessions: PPH and account session access records
CREATE TABLE IF NOT EXISTS public.kl_sessions (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  user_type         text        NOT NULL CHECK (user_type IN ('guest','professional')),
  tier              text        NOT NULL CHECK (tier IN ('guest','per_session','monthly')),
  product_type      text        NOT NULL, -- kl_guest_quick, kl_pro_day, etc.
  email_hash        text,                 -- SHA-256 hash for guest users
  stripe_payment_id text,
  jwt_issued_at     timestamptz,
  expires_at        timestamptz NOT NULL,
  status            text        NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','refunded','archived')),
  created_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.kl_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_sessions_owner_select"
  ON public.kl_sessions FOR SELECT
  USING (auth.uid() = user_id);

-- kl_access_log: instrument view event log
CREATE TABLE IF NOT EXISTS public.kl_access_log (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id     uuid        REFERENCES public.kl_sessions(id) ON DELETE SET NULL,
  user_id        uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  instrument_id  uuid,
  event_type     text        NOT NULL CHECK (event_type IN ('view','download','search','ai_query','report_generate')),
  metadata       jsonb       NOT NULL DEFAULT '{}',
  created_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.kl_access_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_access_log_owner_select"
  ON public.kl_access_log FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "kl_access_log_service_insert"
  ON public.kl_access_log FOR INSERT
  WITH CHECK (true); -- Edge Functions use service role

-- kl_consent_log: GDPR/PECR consent audit trail
CREATE TABLE IF NOT EXISTS public.kl_consent_log (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  email_hash      text,
  consent_type    text        NOT NULL CHECK (consent_type IN ('marketing_email','research_contact','session_terms','platform_terms')),
  granted         boolean     NOT NULL,
  ip_hash         text,
  user_agent_hash text,
  source_page     text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.kl_consent_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_consent_log_owner_select"
  ON public.kl_consent_log FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "kl_consent_log_service_insert"
  ON public.kl_consent_log FOR INSERT
  WITH CHECK (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_kl_sessions_user_id ON public.kl_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_kl_sessions_status ON public.kl_sessions(status);
CREATE INDEX IF NOT EXISTS idx_kl_sessions_expires_at ON public.kl_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_kl_access_log_session_id ON public.kl_access_log(session_id);
CREATE INDEX IF NOT EXISTS idx_kl_access_log_user_id ON public.kl_access_log(user_id);
CREATE INDEX IF NOT EXISTS idx_kl_consent_log_user_id ON public.kl_consent_log(user_id);

