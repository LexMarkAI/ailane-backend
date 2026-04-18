-- Migration: 20260318222141_create_trading_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_trading_tables


-- QSYS Trading Engine — Isolated Tables
-- No references to any Ailane business tables

CREATE TABLE IF NOT EXISTS trading_instruments (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  epic TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT DEFAULT '',
  min_stake NUMERIC DEFAULT 0.01,
  typical_spread NUMERIC DEFAULT 1.0,
  margin_factor NUMERIC DEFAULT 0.10,
  correlation_group TEXT DEFAULT '',
  enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS trading_signals (
  id BIGSERIAL PRIMARY KEY,
  instrument_id TEXT NOT NULL,
  epic TEXT NOT NULL,
  signal_type TEXT NOT NULL,
  direction TEXT NOT NULL,
  strength NUMERIC DEFAULT 0,
  price_at_signal NUMERIC,
  rsi_value NUMERIC,
  ema_fast NUMERIC,
  ema_slow NUMERIC,
  atr_value NUMERIC,
  reasoning TEXT,
  acted_on BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_signals_time ON trading_signals(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_signals_instrument ON trading_signals(instrument_id, created_at DESC);

CREATE TABLE IF NOT EXISTS trading_paper_trades (
  id BIGSERIAL PRIMARY KEY,
  signal_id BIGINT,
  instrument_id TEXT NOT NULL,
  epic TEXT NOT NULL,
  direction TEXT NOT NULL,
  stake NUMERIC NOT NULL,
  entry_price NUMERIC NOT NULL,
  stop_loss NUMERIC,
  take_profit NUMERIC,
  exit_price NUMERIC,
  pnl NUMERIC,
  status TEXT DEFAULT 'OPEN',
  opened_at TIMESTAMPTZ DEFAULT now(),
  closed_at TIMESTAMPTZ,
  reasoning TEXT
);

CREATE TABLE IF NOT EXISTS trading_live_trades (
  id BIGSERIAL PRIMARY KEY,
  signal_id BIGINT,
  instrument_id TEXT NOT NULL,
  epic TEXT NOT NULL,
  direction TEXT NOT NULL,
  stake NUMERIC NOT NULL,
  entry_price NUMERIC NOT NULL,
  stop_loss NUMERIC,
  take_profit NUMERIC,
  exit_price NUMERIC,
  pnl NUMERIC,
  status TEXT DEFAULT 'OPEN',
  deal_id TEXT,
  deal_reference TEXT,
  opened_at TIMESTAMPTZ DEFAULT now(),
  closed_at TIMESTAMPTZ,
  reasoning TEXT
);

CREATE TABLE IF NOT EXISTS trading_equity_log (
  id BIGSERIAL PRIMARY KEY,
  equity NUMERIC NOT NULL,
  cash NUMERIC NOT NULL,
  running_pnl NUMERIC,
  n_positions INTEGER,
  drawdown_pct NUMERIC,
  mode TEXT DEFAULT 'paper',
  logged_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS trading_kill_events (
  id BIGSERIAL PRIMARY KEY,
  level TEXT NOT NULL,
  reason TEXT NOT NULL,
  broker TEXT DEFAULT '',
  instrument TEXT DEFAULT '',
  triggered_at TIMESTAMPTZ DEFAULT now(),
  resolved BOOLEAN DEFAULT false,
  resolved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS trading_system_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Insert default system state
INSERT INTO trading_system_state (key, value) VALUES
  ('mode', 'paper'),
  ('system_halted', 'false'),
  ('ig_halted', 'false'),
  ('poly_halted', 'false'),
  ('daily_pnl', '0'),
  ('daily_pnl_date', '2026-01-01'),
  ('consecutive_losses', '0'),
  ('peak_equity', '1150')
ON CONFLICT (key) DO NOTHING;

