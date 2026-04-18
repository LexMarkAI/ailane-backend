-- Migration: 20260321020814_qtailane_stage3_seed_sources
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qtailane_stage3_seed_sources


-- ============================================================
-- QTAILANE STAGE 3 — MIGRATION 3: SEED EVIDENCE SOURCE REGISTRY
-- Authority: QTAILANE-BUILD-001 Stage 3 / QTAILANE-MTH-005 §3.1
-- ============================================================

-- ═══════════════ PRIMARY WIRE SERVICES ═══════════════
INSERT INTO qtailane_evidence_sources (source_name, source_class, source_type, trust_score, trust_basis, is_primary, independence_group, license_type, covers_categories, covers_jurisdictions) VALUES
('Reuters', 'PRIMARY_WIRE', 'wire_service', 0.92, 'Established wire service with multi-decade track record; primary source for financial and political news; editorially independent', true, 'thomson_reuters', 'commercial', '{ELECTORAL,CENTRAL_BANK,GEOPOLITICAL,CORPORATE_EVENT,ECONOMIC_DATA}', '{US,UK,EU,GLOBAL}'),
('Associated Press', 'PRIMARY_WIRE', 'wire_service', 0.90, 'Non-profit cooperative wire service; original reporting globally; strong editorial standards', true, 'ap_network', 'api_terms', '{ELECTORAL,GEOPOLITICAL,CORPORATE_EVENT}', '{US,UK,EU,GLOBAL}'),
('Bloomberg', 'PRIMARY_WIRE', 'wire_service', 0.91, 'Financial-specialist wire service; terminal data provides market-moving intelligence; strong sourcing standards', true, 'bloomberg_lp', 'commercial', '{CENTRAL_BANK,CORPORATE_EVENT,ECONOMIC_DATA}', '{US,UK,EU,GLOBAL}'),
('AFP', 'PRIMARY_WIRE', 'wire_service', 0.88, 'French state wire service with global network; original reporting in conflict zones; editorially independent from government', true, 'afp_network', 'commercial', '{GEOPOLITICAL,ELECTORAL}', '{EU,GLOBAL}');

-- ═══════════════ PRIMARY OFFICIAL SOURCES ═══════════════
INSERT INTO qtailane_evidence_sources (source_name, source_class, source_type, trust_score, trust_basis, is_primary, independence_group, license_type, covers_categories, covers_jurisdictions) VALUES
('Federal Reserve', 'PRIMARY_OFFICIAL', 'government', 0.98, 'Authoritative source for US monetary policy; FOMC statements and minutes are primary documents; zero intermediation', true, 'us_federal_reserve', 'public', '{CENTRAL_BANK,ECONOMIC_DATA}', '{US}'),
('Bank of England', 'PRIMARY_OFFICIAL', 'government', 0.97, 'Authoritative source for UK monetary policy; MPC minutes and decisions; Inflation Report', true, 'uk_boe', 'public', '{CENTRAL_BANK,ECONOMIC_DATA}', '{UK}'),
('ECB', 'PRIMARY_OFFICIAL', 'government', 0.97, 'European Central Bank; authoritative for eurozone monetary policy', true, 'ecb_eu', 'public', '{CENTRAL_BANK,ECONOMIC_DATA}', '{EU}'),
('US Bureau of Labor Statistics', 'PRIMARY_OFFICIAL', 'government', 0.96, 'Official US employment and inflation data; NFP, CPI, PPI releases', true, 'us_bls', 'public', '{ECONOMIC_DATA}', '{US}'),
('UK ONS', 'PRIMARY_OFFICIAL', 'government', 0.95, 'Office for National Statistics; UK GDP, CPI, employment data', true, 'uk_ons', 'public', '{ECONOMIC_DATA}', '{UK}'),
('SEC EDGAR', 'PRIMARY_OFFICIAL', 'government', 0.97, 'US Securities and Exchange Commission filings; 10-K, 10-Q, 8-K, proxy statements', true, 'us_sec', 'public', '{CORPORATE_EVENT}', '{US}'),
('UK Companies House', 'PRIMARY_OFFICIAL', 'government', 0.94, 'Official UK corporate filings; confirmation statements, accounts, directorships', true, 'uk_ch', 'public', '{CORPORATE_EVENT}', '{UK}'),
('FDA', 'PRIMARY_OFFICIAL', 'government', 0.96, 'US Food and Drug Administration; drug approvals, clinical holds, PDUFA dates', true, 'us_fda', 'public', '{SCIENTIFIC_REGULATORY}', '{US}'),
('UK Parliament', 'PRIMARY_OFFICIAL', 'government', 0.93, 'Hansard, committee reports, bills, statutory instruments; primary legislative source', true, 'uk_parliament', 'public', '{ELECTORAL,SCIENTIFIC_REGULATORY}', '{UK}'),
('White House', 'PRIMARY_OFFICIAL', 'government', 0.90, 'Official presidential statements, executive orders, press briefings; primary but politically positioned', true, 'us_white_house', 'public', '{ELECTORAL,GEOPOLITICAL}', '{US}');

-- ═══════════════ PRIMARY ECONOMIC DATA ═══════════════
INSERT INTO qtailane_evidence_sources (source_name, source_class, source_type, trust_score, trust_basis, is_primary, independence_group, license_type, covers_categories, covers_jurisdictions) VALUES
('FRED (Federal Reserve Economic Data)', 'PRIMARY_ECONOMIC', 'economic_data', 0.97, 'St Louis Fed data repository; aggregates official US economic time series', true, 'us_fred', 'public', '{ECONOMIC_DATA,CENTRAL_BANK}', '{US}'),
('Eurostat', 'PRIMARY_ECONOMIC', 'economic_data', 0.94, 'Official EU statistical office; GDP, inflation, employment across EU member states', true, 'eu_eurostat', 'public', '{ECONOMIC_DATA}', '{EU}'),
('IMF Data', 'PRIMARY_ECONOMIC', 'economic_data', 0.93, 'International Monetary Fund data and forecasts; WEO, GFSR, Article IV consultations', true, 'imf', 'public', '{ECONOMIC_DATA,GEOPOLITICAL}', '{GLOBAL}');

-- ═══════════════ DERIVATIVE NARRATIVE SOURCES ═══════════════
INSERT INTO qtailane_evidence_sources (source_name, source_class, source_type, trust_score, trust_basis, is_primary, independence_group, known_biases, license_type, covers_categories, covers_jurisdictions) VALUES
('X/Twitter Trends', 'DERIVATIVE_NARRATIVE', 'social_media', 0.25, 'Social media aggregate; high noise, narrative stress indicator only; not evidence of world state', false, 'x_twitter', 'Amplification bias; bot contamination; recency bias; political polarisation', 'api_terms', '{ELECTORAL,GEOPOLITICAL,CORPORATE_EVENT}', '{US,UK,EU,GLOBAL}'),
('Reddit Sentiment', 'DERIVATIVE_NARRATIVE', 'social_media', 0.20, 'Aggregate sentiment from relevant subreddits; retail sentiment indicator; not evidence of world state', false, 'reddit', 'Self-selection bias; echo chamber effects; retail-skewed', 'api_terms', '{CORPORATE_EVENT,ECONOMIC_DATA}', '{US,GLOBAL}'),
('Google News Aggregate', 'DERIVATIVE_NARRATIVE', 'aggregator', 0.35, 'News aggregator; useful for volume signals and narrative stress; not independent — aggregates primary sources', false, 'google_news', 'Selection bias toward engagement; not independent reporting', 'public', '{ELECTORAL,GEOPOLITICAL,CORPORATE_EVENT,ECONOMIC_DATA}', '{GLOBAL}');

-- ═══════════════ SOURCE ANCESTRY RELATIONSHIPS ═══════════════
-- Google News derives from wire services
INSERT INTO qtailane_source_ancestry (child_source_id, parent_source_id, relationship_type, confidence, evidence_for_link)
SELECT 
  (SELECT id FROM qtailane_evidence_sources WHERE source_name = 'Google News Aggregate'),
  parent.id,
  'SYNDICATES',
  0.95,
  'Google News aggregates and re-ranks wire service content'
FROM qtailane_evidence_sources parent
WHERE parent.source_name IN ('Reuters', 'Associated Press', 'Bloomberg', 'AFP');

-- Seed evidence connectors in connector_status
INSERT INTO qtailane_connector_status (venue, connector_name, status, connector_type) VALUES
('PAPER', 'evidence-news-poller', 'UNKNOWN', 'EVIDENCE'),
('PAPER', 'evidence-official-poller', 'UNKNOWN', 'EVIDENCE'),
('PAPER', 'evidence-economic-poller', 'UNKNOWN', 'EVIDENCE'),
('PAPER', 'evidence-narrative-poller', 'UNKNOWN', 'EVIDENCE');

-- Audit
INSERT INTO qtailane_audit_log (action, action_category, severity, actor_type, actor_id, detail)
VALUES ('EVIDENCE_SOURCE_REGISTRY_SEEDED', 'SYSTEM', 'INFO', 'SYSTEM', 'stage3_build',
  jsonb_build_object(
    'primary_wire', 4, 'primary_official', 10, 'primary_economic', 3,
    'derivative_narrative', 3, 'ancestry_links', 4, 'evidence_connectors', 4
  ));

