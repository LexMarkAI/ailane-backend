-- Migration: 20260410142829_create_kl_account_profiles_and_session_rls
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_kl_account_profiles_and_session_rls

-- kl_account_profiles (KLAC-001 §10)
CREATE TABLE IF NOT EXISTS kl_account_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_tier TEXT NOT NULL DEFAULT 'per_session',
  display_name TEXT,
  monthly_active BOOLEAN NOT NULL DEFAULT false,
  stripe_customer_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE kl_account_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile" ON kl_account_profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile" ON kl_account_profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- RLS on kl_sessions for per-session user self-read
CREATE POLICY "Users can read own sessions" ON kl_sessions
  FOR SELECT USING (auth.uid() = user_id);
