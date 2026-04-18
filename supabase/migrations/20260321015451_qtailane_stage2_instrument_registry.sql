-- Migration: 20260321015451_qtailane_stage2_instrument_registry
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qtailane_stage2_instrument_registry


-- ============================================================
-- QTAILANE STAGE 2 — MIGRATION 1: INSTRUMENT REGISTRY & CONNECTOR STATUS
-- Authority: QTAILANE-BUILD-001 Stage 2
-- Purpose: Track all tradeable instruments across venues and
--          monitor connector health for each data feed.
-- ============================================================

-- 1. INSTRUMENT REGISTRY
-- Master list of all instruments/contracts the platform can trade or monitor.
-- One row per venue+instrument combination.
CREATE TABLE qtailane_instruments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue             qtailane_venue NOT NULL,
  instrument_id     TEXT NOT NULL,                -- venue-native identifier (epic, slug, ticker)
  display_name      TEXT NOT NULL,                -- human-readable name
  instrument_type   TEXT NOT NULL,                -- 'CFD', 'BINARY_CONTRACT', 'EVENT_CONTRACT'
  asset_class       TEXT,                         -- 'FX', 'INDEX', 'COMMODITY', 'EQUITY', 'CRYPTO', 'EVENT'
  
  -- Venue-specific metadata
  venue_metadata    JSONB NOT NULL DEFAULT '{}',  -- epic details, margin reqs, contract specs
  
  -- Trading parameters
  min_size          FLOAT,
  max_size          FLOAT,
  size_increment    FLOAT,
  margin_factor     FLOAT,                        -- margin requirement as fraction
  
  -- Market hours
  market_hours      JSONB,                        -- {open: "HH:MM", close: "HH:MM", timezone: "tz", days: [1-5]}
  is_market_open    BOOLEAN NOT NULL DEFAULT false,
  
  -- Monitoring state
  is_active         BOOLEAN NOT NULL DEFAULT true,
  is_tradeable      BOOLEAN NOT NULL DEFAULT false, -- only true after full validation
  last_price        FLOAT,
  last_price_at     TIMESTAMPTZ,
  avg_daily_volume  FLOAT,                        -- 7-day ADV for reflexivity calculations
  avg_spread        FLOAT,                        -- average bid-ask spread
  
  -- Category mapping for probability objects
  event_category    qtailane_event_category,       -- maps to probability object categories
  
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT uq_qtailane_instrument UNIQUE (venue, instrument_id)
);

CREATE INDEX idx_qtailane_instruments_venue ON qtailane_instruments(venue);
CREATE INDEX idx_qtailane_instruments_active ON qtailane_instruments(is_active) WHERE is_active = true;
CREATE INDEX idx_qtailane_instruments_type ON qtailane_instruments(instrument_type);
CREATE INDEX idx_qtailane_instruments_asset ON qtailane_instruments(asset_class);

-- 2. CONNECTOR STATUS (health monitoring per venue feed)
CREATE TABLE qtailane_connector_status (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue             qtailane_venue NOT NULL,
  connector_name    TEXT NOT NULL,                -- 'ig-price-poller', 'polymarket-ws', 'kalshi-poller'
  
  -- Health metrics
  status            TEXT NOT NULL DEFAULT 'UNKNOWN'
                    CHECK (status IN ('HEALTHY','DEGRADED','STALE','FAILED','UNKNOWN')),
  last_heartbeat    TIMESTAMPTZ,
  last_data_received TIMESTAMPTZ,
  consecutive_failures INTEGER NOT NULL DEFAULT 0,
  
  -- Performance
  avg_latency_ms    INTEGER,                      -- average ingestion latency
  records_last_hour INTEGER DEFAULT 0,
  records_last_day  INTEGER DEFAULT 0,
  
  -- Error tracking
  last_error        TEXT,
  last_error_at     TIMESTAMPTZ,
  error_count_24h   INTEGER DEFAULT 0,
  
  -- Rate limit tracking
  rate_limit_remaining INTEGER,
  rate_limit_reset_at  TIMESTAMPTZ,
  
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT uq_qtailane_connector UNIQUE (venue, connector_name)
);

CREATE INDEX idx_qtailane_connector_status ON qtailane_connector_status(status);
CREATE INDEX idx_qtailane_connector_venue ON qtailane_connector_status(venue);

-- 3. MARKET DATA SUMMARIES (permanent retention — survives 90-day raw purge)
-- Daily statistical summaries computed from raw data before purge.
CREATE TABLE qtailane_market_data_summaries (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue             qtailane_venue NOT NULL,
  instrument        TEXT NOT NULL,
  summary_date      DATE NOT NULL,
  timeframe         TEXT NOT NULL DEFAULT '1d',
  
  -- OHLCV summary
  open_price        FLOAT,
  high_price        FLOAT NOT NULL,
  low_price         FLOAT NOT NULL,
  close_price       FLOAT NOT NULL,
  vwap              FLOAT,                        -- volume-weighted average price
  total_volume      FLOAT,
  
  -- Spread and depth
  avg_spread        FLOAT,
  max_spread        FLOAT,
  avg_depth_bid     FLOAT,
  avg_depth_ask     FLOAT,
  
  -- Volatility
  intraday_range    FLOAT,                        -- (high - low) / close
  tick_count        INTEGER,                      -- number of raw data points
  
  -- ADV computation
  rolling_7d_adv    FLOAT,                        -- 7-day average daily volume
  rolling_30d_adv   FLOAT,                        -- 30-day average daily volume
  
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT uq_qtailane_summary UNIQUE (venue, instrument, summary_date, timeframe)
);

CREATE INDEX idx_qtailane_summaries_lookup ON qtailane_market_data_summaries(venue, instrument, summary_date DESC);
CREATE INDEX idx_qtailane_summaries_date ON qtailane_market_data_summaries(summary_date DESC);

-- Auto-update triggers
CREATE TRIGGER trg_qtailane_instruments_updated 
  BEFORE UPDATE ON qtailane_instruments 
  FOR EACH ROW EXECUTE FUNCTION qtailane_set_updated_at();

CREATE TRIGGER trg_qtailane_connector_updated 
  BEFORE UPDATE ON qtailane_connector_status 
  FOR EACH ROW EXECUTE FUNCTION qtailane_set_updated_at();

-- RLS
ALTER TABLE qtailane_instruments ENABLE ROW LEVEL SECURITY;
ALTER TABLE qtailane_connector_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE qtailane_market_data_summaries ENABLE ROW LEVEL SECURITY;

CREATE POLICY qtailane_read_instruments ON qtailane_instruments FOR SELECT TO authenticated USING (true);
CREATE POLICY qtailane_read_connector_status ON qtailane_connector_status FOR SELECT TO authenticated USING (true);
CREATE POLICY qtailane_read_summaries ON qtailane_market_data_summaries FOR SELECT TO authenticated USING (true);

