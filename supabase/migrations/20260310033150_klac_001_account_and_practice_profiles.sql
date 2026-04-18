-- Migration: 20260310033150_klac_001_account_and_practice_profiles
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: klac_001_account_and_practice_profiles


-- ============================================================
-- KLAC-001 — TABLES 1 & 2
-- kl_account_profiles + kl_practice_profiles
-- ============================================================

CREATE TABLE IF NOT EXISTS public.kl_account_profiles (
  id                     uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                uuid    NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name           text    NOT NULL,
  role_type              text    CHECK (role_type IN ('solicitor','hr_consultant','in_house_counsel','underwriter','ma_professional','other')),
  organisation           text,
  primary_sector         text,
  subscription_tier      text    NOT NULL DEFAULT 'per_session' CHECK (subscription_tier IN ('guest','per_session','monthly','operational','governance','institutional')),
  stripe_customer_id     text,
  stripe_monthly_sub_id  text,
  monthly_active         boolean NOT NULL DEFAULT false,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.kl_account_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_account_profiles_owner_select"
  ON public.kl_account_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "kl_account_profiles_owner_update"
  ON public.kl_account_profiles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "kl_account_profiles_owner_insert"
  ON public.kl_account_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- updated_at trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE TRIGGER kl_account_profiles_updated_at
  BEFORE UPDATE ON public.kl_account_profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----

CREATE TABLE IF NOT EXISTS public.kl_practice_profiles (
  id                     uuid      PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                uuid      NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  sector_weights         jsonb     NOT NULL DEFAULT '{}',
  instrument_affinity    jsonb     NOT NULL DEFAULT '{}',
  analysis_depth_pref    text      DEFAULT 'standard' CHECK (analysis_depth_pref IN ('summary','standard','deep_constitutional')),
  role_framing           text      DEFAULT 'professional',
  practice_keywords      text[]    NOT NULL DEFAULT '{}',
  recurring_instruments  uuid[]    NOT NULL DEFAULT '{}',
  session_count          integer   NOT NULL DEFAULT 0,
  last_updated           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.kl_practice_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_practice_profiles_owner_select"
  ON public.kl_practice_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "kl_practice_profiles_owner_update"
  ON public.kl_practice_profiles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "kl_practice_profiles_owner_insert"
  ON public.kl_practice_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_kl_account_profiles_user_id ON public.kl_account_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_kl_account_profiles_subscription_tier ON public.kl_account_profiles(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_kl_practice_profiles_user_id ON public.kl_practice_profiles(user_id);

