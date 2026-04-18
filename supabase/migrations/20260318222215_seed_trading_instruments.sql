-- Migration: 20260318222215_seed_trading_instruments
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: seed_trading_instruments


INSERT INTO trading_instruments (id, name, epic, category, subcategory, min_stake, typical_spread, margin_factor, correlation_group, enabled) VALUES
-- COMMODITIES
('oil_us_crude', 'Oil - US Crude', 'CC.D.CL.USS.IP', 'commodity', 'energy', 0.01, 3.0, 0.10, 'energy', true),
('oil_brent', 'Oil - Brent Crude', 'CC.D.LCO.USS.IP', 'commodity', 'energy', 0.01, 3.0, 0.10, 'energy', true),
('natural_gas', 'Natural Gas', 'CC.D.NG.USS.IP', 'commodity', 'energy', 0.01, 3.0, 0.20, 'energy', true),
('gold', 'Spot Gold', 'CS.D.USCGC.TODAY.IP', 'commodity', 'precious_metals', 0.01, 0.3, 0.05, 'precious_metals', true),
('silver', 'Spot Silver', 'CS.D.USCSI.TODAY.IP', 'commodity', 'precious_metals', 0.01, 3.0, 0.10, 'precious_metals', true),
('platinum', 'Platinum', 'CC.D.PL.USS.IP', 'commodity', 'precious_metals', 0.01, 3.0, 0.10, 'precious_metals', true),
('copper', 'Copper', 'CC.D.HG.USS.IP', 'commodity', 'industrial_metals', 0.01, 3.0, 0.10, 'industrial_metals', true),
-- INDICES
('ftse_100', 'FTSE 100', 'IX.D.FTSE.DAILY.IP', 'index', 'uk', 0.10, 1.0, 0.05, 'uk_index', true),
('sp500', 'S&P 500', 'IX.D.SPTRD.DAILY.IP', 'index', 'us', 0.10, 0.4, 0.05, 'us_index', true),
('nasdaq', 'Nasdaq 100', 'IX.D.NASDAQ.CASH.IP', 'index', 'us', 0.10, 1.0, 0.05, 'us_index', true),
('dow_jones', 'Wall Street', 'IX.D.DOW.DAILY.IP', 'index', 'us', 0.10, 1.6, 0.05, 'us_index', true),
('dax', 'Germany 40 (DAX)', 'IX.D.DAX.DAILY.IP', 'index', 'europe', 0.10, 1.2, 0.05, 'eu_index', true),
('cac40', 'France 40', 'IX.D.CAC.DAILY.IP', 'index', 'europe', 0.10, 1.0, 0.05, 'eu_index', true),
('nikkei', 'Japan 225', 'IX.D.NIKKEI.DAILY.IP', 'index', 'asia', 0.10, 7.0, 0.05, 'asia_index', true),
('hang_seng', 'Hong Kong HS50', 'IX.D.HANGSENG.DAILY.IP', 'index', 'asia', 0.10, 8.0, 0.05, 'asia_index', true),
('asx200', 'Australia 200', 'IX.D.ASX.DAILY.IP', 'index', 'asia', 0.10, 1.0, 0.05, 'asia_index', true),
('russell2000', 'US Russell 2000', 'IX.D.RUSSELL.DAILY.IP', 'index', 'us', 0.10, 0.3, 0.05, 'us_index', true),
('vix', 'Volatility Index', 'IX.D.VIX.DAILY.IP', 'volatility', 'vix', 0.10, 0.1, 0.20, 'volatility', true),
-- FOREX MAJORS
('eur_usd', 'EUR/USD', 'CS.D.EURUSD.TODAY.IP', 'forex', 'major', 0.01, 0.6, 0.0333, 'fx_eur', true),
('gbp_usd', 'GBP/USD', 'CS.D.GBPUSD.TODAY.IP', 'forex', 'major', 0.01, 0.6, 0.0333, 'fx_gbp', true),
('usd_jpy', 'USD/JPY', 'CS.D.USDJPY.TODAY.IP', 'forex', 'major', 0.01, 0.7, 0.0333, 'fx_jpy', true),
('usd_chf', 'USD/CHF', 'CS.D.USDCHF.TODAY.IP', 'forex', 'major', 0.01, 1.5, 0.0333, 'fx_chf', true),
('aud_usd', 'AUD/USD', 'CS.D.AUDUSD.TODAY.IP', 'forex', 'major', 0.01, 0.6, 0.0333, 'fx_aud', true),
('usd_cad', 'USD/CAD', 'CS.D.USDCAD.TODAY.IP', 'forex', 'major', 0.01, 1.3, 0.0333, 'fx_cad', true),
('nzd_usd', 'NZD/USD', 'CS.D.NZDUSD.TODAY.IP', 'forex', 'major', 0.01, 1.8, 0.0333, 'fx_nzd', true),
-- FOREX CROSSES
('eur_gbp', 'EUR/GBP', 'CS.D.EURGBP.TODAY.IP', 'forex', 'cross', 0.01, 0.9, 0.0333, 'fx_eur', true),
('eur_jpy', 'EUR/JPY', 'CS.D.EURJPY.TODAY.IP', 'forex', 'cross', 0.01, 1.5, 0.0333, 'fx_eur', true),
('gbp_jpy', 'GBP/JPY', 'CS.D.GBPJPY.TODAY.IP', 'forex', 'cross', 0.01, 2.0, 0.0333, 'fx_gbp', true),
('eur_aud', 'EUR/AUD', 'CS.D.EURAUD.TODAY.IP', 'forex', 'cross', 0.01, 2.0, 0.0333, 'fx_eur', true),
('gbp_aud', 'GBP/AUD', 'CS.D.GBPAUD.TODAY.IP', 'forex', 'cross', 0.01, 3.0, 0.0333, 'fx_gbp', true),
('aud_jpy', 'AUD/JPY', 'CS.D.AUDJPY.TODAY.IP', 'forex', 'cross', 0.01, 1.5, 0.0333, 'fx_aud', true),
('eur_chf', 'EUR/CHF', 'CS.D.EURCHF.TODAY.IP', 'forex', 'cross', 0.01, 2.0, 0.0333, 'fx_eur', true),
-- CRYPTO
('bitcoin', 'Bitcoin', 'CS.D.BITCOIN.TODAY.IP', 'crypto', 'major', 0.01, 30.0, 0.50, 'crypto_btc', true),
('ethereum', 'Ethereum', 'CS.D.ETHUSD.TODAY.IP', 'crypto', 'major', 0.01, 3.0, 0.50, 'crypto_eth', true),
-- BONDS / RATES
('us_10yr', 'US T-Bond', 'IR.D.10YTNOTE.FWM2.IP', 'bonds', 'us', 0.01, 3.0, 0.05, 'bonds_us', true),
('uk_gilt', 'UK Long Gilt', 'IR.D.GILTLNG.FWM2.IP', 'bonds', 'uk', 0.01, 3.0, 0.05, 'bonds_uk', true),
('bund', 'Germany Bund', 'IR.D.FBUND.FWM2.IP', 'bonds', 'europe', 0.01, 2.0, 0.05, 'bonds_eu', true)
ON CONFLICT (id) DO UPDATE SET
  epic = EXCLUDED.epic,
  name = EXCLUDED.name,
  enabled = EXCLUDED.enabled;

