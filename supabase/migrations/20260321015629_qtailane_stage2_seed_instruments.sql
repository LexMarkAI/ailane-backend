-- Migration: 20260321015629_qtailane_stage2_seed_instruments
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qtailane_stage2_seed_instruments


-- ============================================================
-- QTAILANE STAGE 2 — MIGRATION 3: SEED INSTRUMENT REGISTRY
-- Authority: QTAILANE-BUILD-001 Stage 2
-- IG Markets 40+ instruments + Polymarket + Kalshi placeholders
-- ============================================================

-- IG MARKETS — FX MAJORS
INSERT INTO qtailane_instruments (venue, instrument_id, display_name, instrument_type, asset_class, venue_metadata, is_active, is_tradeable) VALUES
('IG_MARKETS', 'CS.D.GBPUSD.TODAY.IP', 'GBP/USD', 'CFD', 'FX', '{"epic":"CS.D.GBPUSD.TODAY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'CS.D.EURUSD.TODAY.IP', 'EUR/USD', 'CFD', 'FX', '{"epic":"CS.D.EURUSD.TODAY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'CS.D.USDJPY.TODAY.IP', 'USD/JPY', 'CFD', 'FX', '{"epic":"CS.D.USDJPY.TODAY.IP","currency":"JPY"}', true, true),
('IG_MARKETS', 'CS.D.AUDUSD.TODAY.IP', 'AUD/USD', 'CFD', 'FX', '{"epic":"CS.D.AUDUSD.TODAY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'CS.D.USDCAD.TODAY.IP', 'USD/CAD', 'CFD', 'FX', '{"epic":"CS.D.USDCAD.TODAY.IP","currency":"CAD"}', true, true),
('IG_MARKETS', 'CS.D.NZDUSD.TODAY.IP', 'NZD/USD', 'CFD', 'FX', '{"epic":"CS.D.NZDUSD.TODAY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'CS.D.USDCHF.TODAY.IP', 'USD/CHF', 'CFD', 'FX', '{"epic":"CS.D.USDCHF.TODAY.IP","currency":"CHF"}', true, true),
('IG_MARKETS', 'CS.D.EURGBP.TODAY.IP', 'EUR/GBP', 'CFD', 'FX', '{"epic":"CS.D.EURGBP.TODAY.IP","currency":"GBP"}', true, true);

-- IG MARKETS — INDICES
INSERT INTO qtailane_instruments (venue, instrument_id, display_name, instrument_type, asset_class, venue_metadata, is_active, is_tradeable) VALUES
('IG_MARKETS', 'IX.D.FTSE.DAILY.IP', 'FTSE 100', 'CFD', 'INDEX', '{"epic":"IX.D.FTSE.DAILY.IP","currency":"GBP"}', true, true),
('IG_MARKETS', 'IX.D.DOW.DAILY.IP', 'Dow Jones', 'CFD', 'INDEX', '{"epic":"IX.D.DOW.DAILY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'IX.D.NASDAQ.DAILY.IP', 'NASDAQ 100', 'CFD', 'INDEX', '{"epic":"IX.D.NASDAQ.DAILY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'IX.D.SPTRD.DAILY.IP', 'S&P 500', 'CFD', 'INDEX', '{"epic":"IX.D.SPTRD.DAILY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'IX.D.DAX.DAILY.IP', 'DAX 40', 'CFD', 'INDEX', '{"epic":"IX.D.DAX.DAILY.IP","currency":"EUR"}', true, true),
('IG_MARKETS', 'IX.D.NIKKEI.DAILY.IP', 'Nikkei 225', 'CFD', 'INDEX', '{"epic":"IX.D.NIKKEI.DAILY.IP","currency":"JPY"}', true, true),
('IG_MARKETS', 'IX.D.HANGSENG.DAILY.IP', 'Hang Seng', 'CFD', 'INDEX', '{"epic":"IX.D.HANGSENG.DAILY.IP","currency":"HKD"}', true, true),
('IG_MARKETS', 'IX.D.ASX.DAILY.IP', 'ASX 200', 'CFD', 'INDEX', '{"epic":"IX.D.ASX.DAILY.IP","currency":"AUD"}', true, true);

-- IG MARKETS — COMMODITIES
INSERT INTO qtailane_instruments (venue, instrument_id, display_name, instrument_type, asset_class, venue_metadata, is_active, is_tradeable) VALUES
('IG_MARKETS', 'CS.D.USCGC.TODAY.IP', 'Gold (USD)', 'CFD', 'COMMODITY', '{"epic":"CS.D.USCGC.TODAY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'CS.D.USCSI.TODAY.IP', 'Silver (USD)', 'CFD', 'COMMODITY', '{"epic":"CS.D.USCSI.TODAY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'CC.D.CL.UNC.IP', 'Crude Oil (WTI)', 'CFD', 'COMMODITY', '{"epic":"CC.D.CL.UNC.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'CC.D.LCO.UNC.IP', 'Brent Crude', 'CFD', 'COMMODITY', '{"epic":"CC.D.LCO.UNC.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'CC.D.NG.UNC.IP', 'Natural Gas', 'CFD', 'COMMODITY', '{"epic":"CC.D.NG.UNC.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'CS.D.USCCO.TODAY.IP', 'Copper (USD)', 'CFD', 'COMMODITY', '{"epic":"CS.D.USCCO.TODAY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'CC.D.W.UNC.IP', 'Wheat', 'CFD', 'COMMODITY', '{"epic":"CC.D.W.UNC.IP","currency":"USD"}', true, true);

-- IG MARKETS — EQUITIES (top movers)
INSERT INTO qtailane_instruments (venue, instrument_id, display_name, instrument_type, asset_class, venue_metadata, is_active, is_tradeable) VALUES
('IG_MARKETS', 'KA.D.AAPL.DAILY.IP', 'Apple Inc', 'CFD', 'EQUITY', '{"epic":"KA.D.AAPL.DAILY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'KA.D.MSFT.DAILY.IP', 'Microsoft', 'CFD', 'EQUITY', '{"epic":"KA.D.MSFT.DAILY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'KA.D.NVDA.DAILY.IP', 'NVIDIA', 'CFD', 'EQUITY', '{"epic":"KA.D.NVDA.DAILY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'KA.D.TSLA.DAILY.IP', 'Tesla', 'CFD', 'EQUITY', '{"epic":"KA.D.TSLA.DAILY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'KA.D.AMZN.DAILY.IP', 'Amazon', 'CFD', 'EQUITY', '{"epic":"KA.D.AMZN.DAILY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'KA.D.GOOGL.DAILY.IP', 'Alphabet (Google)', 'CFD', 'EQUITY', '{"epic":"KA.D.GOOGL.DAILY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'KA.D.META.DAILY.IP', 'Meta Platforms', 'CFD', 'EQUITY', '{"epic":"KA.D.META.DAILY.IP","currency":"USD"}', true, true);

-- IG MARKETS — CRYPTO
INSERT INTO qtailane_instruments (venue, instrument_id, display_name, instrument_type, asset_class, venue_metadata, is_active, is_tradeable) VALUES
('IG_MARKETS', 'CS.D.BITCOIN.TODAY.IP', 'Bitcoin (USD)', 'CFD', 'CRYPTO', '{"epic":"CS.D.BITCOIN.TODAY.IP","currency":"USD"}', true, true),
('IG_MARKETS', 'CS.D.ETHUSD.TODAY.IP', 'Ethereum (USD)', 'CFD', 'CRYPTO', '{"epic":"CS.D.ETHUSD.TODAY.IP","currency":"USD"}', true, true);

-- IG MARKETS — BONDS
INSERT INTO qtailane_instruments (venue, instrument_id, display_name, instrument_type, asset_class, venue_metadata, is_active, is_tradeable) VALUES
('IG_MARKETS', 'IR.D.10YGILTS.FWM2.IP', 'UK 10Y Gilt', 'CFD', 'INDEX', '{"epic":"IR.D.10YGILTS.FWM2.IP","currency":"GBP"}', true, true),
('IG_MARKETS', 'IR.D.USTB10Y.FWM1.IP', 'US 10Y Treasury', 'CFD', 'INDEX', '{"epic":"IR.D.USTB10Y.FWM1.IP","currency":"USD"}', true, true);

-- POLYMARKET — placeholder entries (populated dynamically by connector)
INSERT INTO qtailane_instruments (venue, instrument_id, display_name, instrument_type, asset_class, event_category, venue_metadata, is_active, is_tradeable) VALUES
('POLYMARKET', 'polymarket-discovery', 'Polymarket Auto-Discovery', 'BINARY_CONTRACT', 'EVENT', 'OTHER', 
 '{"note":"Polymarket instruments are discovered dynamically by the connector. This is a placeholder for the discovery process."}', true, false);

-- KALSHI — placeholder entries (populated dynamically by connector)
INSERT INTO qtailane_instruments (venue, instrument_id, display_name, instrument_type, asset_class, event_category, venue_metadata, is_active, is_tradeable) VALUES
('KALSHI', 'kalshi-discovery', 'Kalshi Auto-Discovery', 'EVENT_CONTRACT', 'EVENT', 'OTHER',
 '{"note":"Kalshi instruments are discovered dynamically by the connector. This is a placeholder for the discovery process."}', true, false);

-- Seed connector status entries
INSERT INTO qtailane_connector_status (venue, connector_name, status) VALUES
('IG_MARKETS', 'ig-price-poller', 'UNKNOWN'),
('IG_MARKETS', 'ig-streaming', 'UNKNOWN'),
('POLYMARKET', 'polymarket-poller', 'UNKNOWN'),
('KALSHI', 'kalshi-poller', 'UNKNOWN');

-- Audit the seed
INSERT INTO qtailane_audit_log (action, action_category, severity, actor_type, actor_id, detail)
VALUES ('INSTRUMENT_REGISTRY_SEEDED', 'SYSTEM', 'INFO', 'SYSTEM', 'stage2_build',
  jsonb_build_object('ig_instruments', 34, 'polymarket_placeholder', 1, 'kalshi_placeholder', 1, 'connectors', 4));

