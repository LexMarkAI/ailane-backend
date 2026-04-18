-- Migration: 20260321015545_qtailane_stage2_ingestion_functions
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qtailane_stage2_ingestion_functions


-- ============================================================
-- QTAILANE STAGE 2 — MIGRATION 2: INGESTION & SUMMARY FUNCTIONS
-- Authority: QTAILANE-BUILD-001 Stage 2
-- ============================================================

-- 1. BATCH INSERT MARKET DATA
-- Edge Functions call this to write normalised price data.
-- Handles deduplication via ON CONFLICT.
CREATE OR REPLACE FUNCTION qtailane_ingest_market_data(
  p_venue qtailane_venue,
  p_instrument TEXT,
  p_timestamp TIMESTAMPTZ,
  p_close FLOAT,
  p_open FLOAT DEFAULT NULL,
  p_high FLOAT DEFAULT NULL,
  p_low FLOAT DEFAULT NULL,
  p_volume FLOAT DEFAULT NULL,
  p_bid FLOAT DEFAULT NULL,
  p_ask FLOAT DEFAULT NULL,
  p_timeframe TEXT DEFAULT '1m'
)
RETURNS UUID AS $$
DECLARE
  new_id UUID;
  computed_spread FLOAT;
BEGIN
  -- Compute spread if bid and ask provided
  IF p_bid IS NOT NULL AND p_ask IS NOT NULL THEN
    computed_spread := p_ask - p_bid;
  END IF;

  INSERT INTO qtailane_market_data (
    venue, instrument, timestamp, close_price,
    open_price, high_price, low_price, volume,
    bid, ask, spread, timeframe
  ) VALUES (
    p_venue, p_instrument, p_timestamp, p_close,
    p_open, p_high, p_low, p_volume,
    p_bid, p_ask, computed_spread, p_timeframe
  )
  RETURNING id INTO new_id;

  -- Update instrument last price
  UPDATE qtailane_instruments
  SET last_price = p_close,
      last_price_at = p_timestamp,
      avg_spread = CASE 
        WHEN avg_spread IS NULL THEN computed_spread
        WHEN computed_spread IS NOT NULL THEN (avg_spread * 0.95) + (computed_spread * 0.05)  -- EMA
        ELSE avg_spread
      END
  WHERE venue = p_venue AND instrument_id = p_instrument;

  RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. BATCH INSERT (JSON array input for efficiency)
-- Edge Functions can send entire batches in one call.
CREATE OR REPLACE FUNCTION qtailane_ingest_market_data_batch(
  p_data JSONB  -- array of {venue, instrument, timestamp, close, open, high, low, volume, bid, ask, timeframe}
)
RETURNS INTEGER AS $$
DECLARE
  rec JSONB;
  inserted INTEGER := 0;
BEGIN
  FOR rec IN SELECT * FROM jsonb_array_elements(p_data)
  LOOP
    INSERT INTO qtailane_market_data (
      venue, instrument, timestamp, close_price,
      open_price, high_price, low_price, volume,
      bid, ask, spread, timeframe
    ) VALUES (
      (rec->>'venue')::qtailane_venue,
      rec->>'instrument',
      (rec->>'timestamp')::TIMESTAMPTZ,
      (rec->>'close')::FLOAT,
      (rec->>'open')::FLOAT,
      (rec->>'high')::FLOAT,
      (rec->>'low')::FLOAT,
      (rec->>'volume')::FLOAT,
      (rec->>'bid')::FLOAT,
      (rec->>'ask')::FLOAT,
      CASE WHEN rec->>'bid' IS NOT NULL AND rec->>'ask' IS NOT NULL
           THEN (rec->>'ask')::FLOAT - (rec->>'bid')::FLOAT
           ELSE NULL END,
      COALESCE(rec->>'timeframe', '1m')
    );
    inserted := inserted + 1;
  END LOOP;

  -- Log the batch ingestion
  INSERT INTO qtailane_audit_log (action, action_category, severity, actor_type, actor_id, detail)
  VALUES ('MARKET_DATA_BATCH_INGEST', 'SYSTEM', 'INFO', 'SYSTEM', 'market_data_ingester',
    jsonb_build_object('records_inserted', inserted, 'batch_size', jsonb_array_length(p_data)));

  RETURN inserted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. COMPUTE DAILY SUMMARIES
-- Run daily before raw data purge. Aggregates raw ticks into permanent summaries.
CREATE OR REPLACE FUNCTION qtailane_compute_daily_summaries(
  p_date DATE DEFAULT CURRENT_DATE - 1  -- default: yesterday
)
RETURNS INTEGER AS $$
DECLARE
  summary_count INTEGER := 0;
BEGIN
  INSERT INTO qtailane_market_data_summaries (
    venue, instrument, summary_date, timeframe,
    open_price, high_price, low_price, close_price, vwap, total_volume,
    avg_spread, max_spread, avg_depth_bid, avg_depth_ask,
    intraday_range, tick_count
  )
  SELECT
    venue,
    instrument,
    p_date,
    '1d',
    -- OHLCV: first open, max high, min low, last close
    (ARRAY_AGG(open_price ORDER BY timestamp ASC))[1],
    MAX(high_price),
    MIN(low_price),
    (ARRAY_AGG(close_price ORDER BY timestamp DESC))[1],
    -- VWAP
    CASE WHEN SUM(volume) > 0
         THEN SUM(close_price * COALESCE(volume, 0)) / NULLIF(SUM(COALESCE(volume, 0)), 0)
         ELSE NULL END,
    SUM(COALESCE(volume, 0)),
    -- Spread
    AVG(spread),
    MAX(spread),
    AVG(depth_bid),
    AVG(depth_ask),
    -- Volatility
    CASE WHEN (ARRAY_AGG(close_price ORDER BY timestamp DESC))[1] > 0
         THEN (MAX(COALESCE(high_price, close_price)) - MIN(COALESCE(low_price, close_price))) 
              / (ARRAY_AGG(close_price ORDER BY timestamp DESC))[1]
         ELSE NULL END,
    COUNT(*)::INTEGER
  FROM qtailane_market_data
  WHERE timestamp::DATE = p_date
  GROUP BY venue, instrument
  ON CONFLICT (venue, instrument, summary_date, timeframe) 
  DO UPDATE SET
    open_price = EXCLUDED.open_price,
    high_price = EXCLUDED.high_price,
    low_price = EXCLUDED.low_price,
    close_price = EXCLUDED.close_price,
    vwap = EXCLUDED.vwap,
    total_volume = EXCLUDED.total_volume,
    avg_spread = EXCLUDED.avg_spread,
    max_spread = EXCLUDED.max_spread,
    avg_depth_bid = EXCLUDED.avg_depth_bid,
    avg_depth_ask = EXCLUDED.avg_depth_ask,
    intraday_range = EXCLUDED.intraday_range,
    tick_count = EXCLUDED.tick_count;

  GET DIAGNOSTICS summary_count = ROW_COUNT;

  -- Update rolling ADV on instruments
  UPDATE qtailane_instruments i
  SET avg_daily_volume = sub.adv_7d
  FROM (
    SELECT venue, instrument, AVG(total_volume) AS adv_7d
    FROM qtailane_market_data_summaries
    WHERE summary_date >= p_date - 7
    GROUP BY venue, instrument
  ) sub
  WHERE i.venue = sub.venue AND i.instrument_id = sub.instrument;

  -- Audit
  INSERT INTO qtailane_audit_log (action, action_category, severity, actor_type, actor_id, detail)
  VALUES ('DAILY_SUMMARY_COMPUTED', 'SYSTEM', 'INFO', 'SYSTEM', 'summary_engine',
    jsonb_build_object('date', p_date, 'summaries_created', summary_count));

  RETURN summary_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. UPDATE CONNECTOR HEALTH
-- Called by each Edge Function on heartbeat and after each ingestion cycle.
CREATE OR REPLACE FUNCTION qtailane_update_connector_health(
  p_venue qtailane_venue,
  p_connector_name TEXT,
  p_status TEXT,
  p_records_ingested INTEGER DEFAULT 0,
  p_latency_ms INTEGER DEFAULT NULL,
  p_error TEXT DEFAULT NULL,
  p_rate_limit_remaining INTEGER DEFAULT NULL,
  p_rate_limit_reset TIMESTAMPTZ DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO qtailane_connector_status (
    venue, connector_name, status, last_heartbeat, last_data_received,
    avg_latency_ms, records_last_hour, last_error, last_error_at,
    rate_limit_remaining, rate_limit_reset_at
  ) VALUES (
    p_venue, p_connector_name, p_status, now(),
    CASE WHEN p_records_ingested > 0 THEN now() ELSE NULL END,
    p_latency_ms, p_records_ingested, p_error,
    CASE WHEN p_error IS NOT NULL THEN now() ELSE NULL END,
    p_rate_limit_remaining, p_rate_limit_reset
  )
  ON CONFLICT (venue, connector_name) DO UPDATE SET
    status = EXCLUDED.status,
    last_heartbeat = now(),
    last_data_received = CASE 
      WHEN p_records_ingested > 0 THEN now()
      ELSE qtailane_connector_status.last_data_received
    END,
    consecutive_failures = CASE
      WHEN EXCLUDED.status = 'HEALTHY' THEN 0
      WHEN EXCLUDED.status IN ('FAILED','STALE') THEN qtailane_connector_status.consecutive_failures + 1
      ELSE qtailane_connector_status.consecutive_failures
    END,
    avg_latency_ms = CASE
      WHEN p_latency_ms IS NOT NULL AND qtailane_connector_status.avg_latency_ms IS NOT NULL
      THEN ((qtailane_connector_status.avg_latency_ms * 9) + p_latency_ms) / 10  -- rolling avg
      ELSE COALESCE(p_latency_ms, qtailane_connector_status.avg_latency_ms)
    END,
    records_last_hour = CASE
      WHEN p_records_ingested > 0 THEN qtailane_connector_status.records_last_hour + p_records_ingested
      ELSE qtailane_connector_status.records_last_hour
    END,
    last_error = COALESCE(p_error, qtailane_connector_status.last_error),
    last_error_at = CASE WHEN p_error IS NOT NULL THEN now() ELSE qtailane_connector_status.last_error_at END,
    error_count_24h = CASE
      WHEN p_error IS NOT NULL THEN qtailane_connector_status.error_count_24h + 1
      ELSE qtailane_connector_status.error_count_24h
    END,
    rate_limit_remaining = COALESCE(p_rate_limit_remaining, qtailane_connector_status.rate_limit_remaining),
    rate_limit_reset_at = COALESCE(p_rate_limit_reset, qtailane_connector_status.rate_limit_reset_at),
    updated_at = now();

  -- Trigger CB-3 check: if consecutive_failures >= 3, log critical alert
  IF (SELECT consecutive_failures FROM qtailane_connector_status 
      WHERE venue = p_venue AND connector_name = p_connector_name) >= 3 THEN
    INSERT INTO qtailane_audit_log (action, action_category, severity, actor_type, actor_id, detail)
    VALUES ('CONNECTOR_FAILURE_THRESHOLD', 'SYSTEM', 'CRITICAL', 'SYSTEM', 'connector_health',
      jsonb_build_object('venue', p_venue::TEXT, 'connector', p_connector_name,
        'consecutive_failures', 3, 'cb3_candidate', true));
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. STALENESS DETECTOR
-- Returns connectors that have not received data within threshold.
-- Dashboard polls this. CB-3 logic uses this.
CREATE OR REPLACE FUNCTION qtailane_check_connector_staleness(
  p_stale_threshold_seconds INTEGER DEFAULT 120  -- 2 minutes default
)
RETURNS TABLE(
  venue qtailane_venue,
  connector_name TEXT,
  seconds_since_data FLOAT,
  current_status TEXT,
  consecutive_failures INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cs.venue,
    cs.connector_name,
    EXTRACT(EPOCH FROM (now() - cs.last_data_received))::FLOAT AS seconds_since_data,
    cs.status,
    cs.consecutive_failures
  FROM qtailane_connector_status cs
  WHERE cs.last_data_received IS NOT NULL
    AND EXTRACT(EPOCH FROM (now() - cs.last_data_received)) > p_stale_threshold_seconds
  ORDER BY seconds_since_data DESC;
END;
$$ LANGUAGE plpgsql;

-- 6. INSTRUMENT PRICE SNAPSHOT
-- Quick view for dashboard: all active instruments with latest price.
CREATE OR REPLACE VIEW qtailane_instrument_prices AS
SELECT 
  i.id,
  i.venue,
  i.instrument_id,
  i.display_name,
  i.instrument_type,
  i.asset_class,
  i.last_price,
  i.last_price_at,
  i.avg_daily_volume,
  i.avg_spread,
  i.is_market_open,
  i.is_tradeable,
  i.event_category,
  cs.status AS connector_status,
  cs.last_heartbeat AS connector_heartbeat,
  EXTRACT(EPOCH FROM (now() - i.last_price_at))::INTEGER AS seconds_since_update
FROM qtailane_instruments i
LEFT JOIN qtailane_connector_status cs ON cs.venue = i.venue
WHERE i.is_active = true
ORDER BY i.venue, i.asset_class, i.display_name;

