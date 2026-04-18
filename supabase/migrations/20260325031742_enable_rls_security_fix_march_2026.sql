-- Migration: 20260325031742_enable_rls_security_fix_march_2026
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: enable_rls_security_fix_march_2026


-- SECURITY FIX: Enable RLS on all 12 unprotected public tables
-- Triggered by Supabase security advisory 23 Mar 2026
-- All tables get RLS enabled with service_role bypass only
-- Edge Functions using service_role key are unaffected

-- 1. Platform/Config tables
ALTER TABLE public.platform_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stripe_products ENABLE ROW LEVEL SECURITY;

-- 2. AI/Analytics tables  
ALTER TABLE public.clause_fingerprints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tribunal_clause_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.model_performance_log ENABLE ROW LEVEL SECURITY;

-- 3. Trading system tables
ALTER TABLE public.trading_instruments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trading_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trading_paper_trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trading_live_trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trading_equity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trading_kill_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trading_system_state ENABLE ROW LEVEL SECURITY;

-- READ policies for authenticated users (Edge Functions use service_role which bypasses RLS)

-- Platform config: read-only for authenticated users
CREATE POLICY "authenticated_read_platform_config" ON public.platform_config
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_read_stripe_products" ON public.stripe_products
  FOR SELECT TO authenticated USING (true);

-- AI/Analytics: read-only for authenticated users
CREATE POLICY "authenticated_read_clause_fingerprints" ON public.clause_fingerprints
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_read_tribunal_clause_signals" ON public.tribunal_clause_signals
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_read_model_performance_log" ON public.model_performance_log
  FOR SELECT TO authenticated USING (true);

-- Trading: read-only for authenticated users
CREATE POLICY "authenticated_read_trading_instruments" ON public.trading_instruments
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_read_trading_signals" ON public.trading_signals
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_read_trading_paper_trades" ON public.trading_paper_trades
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_read_trading_live_trades" ON public.trading_live_trades
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_read_trading_equity_log" ON public.trading_equity_log
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_read_trading_kill_events" ON public.trading_kill_events
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_read_trading_system_state" ON public.trading_system_state
  FOR SELECT TO authenticated USING (true);

