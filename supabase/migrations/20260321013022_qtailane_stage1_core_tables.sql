-- Migration: 20260321013022_qtailane_stage1_core_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qtailane_stage1_core_tables


-- ============================================================
-- QTAILANE STAGE 1 — MIGRATION 2: CORE TABLES
-- FK dependency order: model_registry → base_rates → regime_states → probability_objects → claim_clusters → positions → trades
-- ============================================================

-- 1. MODEL REGISTRY
CREATE TABLE qtailane_model_registry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version TEXT NOT NULL,
  model_hash TEXT NOT NULL,
  description TEXT,
  change_tier qtailane_change_tier NOT NULL,
  change_card_id TEXT,
  hypothesis TEXT,
  backtest_summary JSONB,
  shadow_run_result JSONB,
  risks_identified TEXT,
  rollback_procedure TEXT NOT NULL,
  reviewer_signoff TEXT,
  deployed_at TIMESTAMPTZ,
  deprecated_at TIMESTAMPTZ,
  is_production BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_qtailane_model_registry_production ON qtailane_model_registry(is_production) WHERE is_production = true;

-- 2. BASE RATE LIBRARY
CREATE TABLE qtailane_base_rates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category qtailane_event_category NOT NULL,
  jurisdiction TEXT NOT NULL,
  conditioning_vars JSONB NOT NULL DEFAULT '{}',
  base_rate FLOAT NOT NULL CHECK (base_rate >= 0 AND base_rate <= 1),
  confidence_band_lo FLOAT NOT NULL CHECK (confidence_band_lo >= 0 AND confidence_band_lo <= 1),
  confidence_band_hi FLOAT NOT NULL CHECK (confidence_band_hi >= 0 AND confidence_band_hi <= 1),
  sample_size INTEGER NOT NULL CHECK (sample_size > 0),
  temporal_range_from DATE,
  temporal_range_to DATE,
  source_citation TEXT NOT NULL,
  source_quality TEXT,
  is_low_confidence BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_base_rate_band CHECK (confidence_band_lo <= base_rate AND base_rate <= confidence_band_hi)
);
CREATE INDEX idx_qtailane_base_rates_lookup ON qtailane_base_rates(category, jurisdiction);

-- 3. REGIME STATES (7 dimensions)
CREATE TABLE qtailane_regime_states (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  narrative_stress FLOAT NOT NULL CHECK (narrative_stress >= 0 AND narrative_stress <= 1),
  source_trust FLOAT NOT NULL CHECK (source_trust >= 0 AND source_trust <= 1),
  volatility_state qtailane_volatility_state NOT NULL,
  liquidity_depth FLOAT NOT NULL CHECK (liquidity_depth >= 0 AND liquidity_depth <= 1),
  temporal_urgency FLOAT NOT NULL CHECK (temporal_urgency >= 0 AND temporal_urgency <= 1),
  manipulation_risk FLOAT NOT NULL CHECK (manipulation_risk >= 0 AND manipulation_risk <= 1),
  crowding_index FLOAT NOT NULL CHECK (crowding_index >= 0 AND crowding_index <= 1),
  computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  computation_method TEXT NOT NULL DEFAULT 'ensemble',
  model_version_id UUID REFERENCES qtailane_model_registry(id),
  is_immutable BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_qtailane_regime_states_computed ON qtailane_regime_states(computed_at DESC);

-- 4. PROBABILITY OBJECTS (MTH-005 §2.2 full field spec)
CREATE TABLE qtailane_probability_objects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_definition TEXT NOT NULL CHECK (char_length(event_definition) <= 500),
  resolution_source TEXT[] NOT NULL,
  ambiguity_score FLOAT CHECK (ambiguity_score >= 0 AND ambiguity_score <= 1),
  category qtailane_event_category NOT NULL,
  jurisdiction TEXT,
  prior_probability FLOAT NOT NULL CHECK (prior_probability >= 0 AND prior_probability <= 1),
  current_posterior FLOAT NOT NULL CHECK (current_posterior >= 0 AND current_posterior <= 1),
  world_state_p FLOAT CHECK (world_state_p >= 0 AND world_state_p <= 1),
  market_state_p FLOAT CHECK (market_state_p >= 0 AND market_state_p <= 1),
  uncertainty_band_lo FLOAT NOT NULL CHECK (uncertainty_band_lo >= 0 AND uncertainty_band_lo <= 1),
  uncertainty_band_hi FLOAT NOT NULL CHECK (uncertainty_band_hi >= 0 AND uncertainty_band_hi <= 1),
  regime_tag_id UUID REFERENCES qtailane_regime_states(id),
  narrative_stress FLOAT CHECK (narrative_stress >= 0 AND narrative_stress <= 1),
  ev_naive FLOAT,
  ev_real FLOAT,
  kelly_fraction FLOAT CHECK (kelly_fraction >= 0 AND kelly_fraction <= 1),
  sigma_model FLOAT CHECK (sigma_model >= 0),
  sigma_exec FLOAT CHECK (sigma_exec >= 0),
  reflexivity_score FLOAT CHECK (reflexivity_score >= 0 AND reflexivity_score <= 1),
  action_state qtailane_action_state NOT NULL DEFAULT 'CREATED',
  previous_action_state qtailane_action_state,
  base_rate_source_id UUID REFERENCES qtailane_base_rates(id),
  model_version_id UUID REFERENCES qtailane_model_registry(id),
  schema_version INTEGER NOT NULL DEFAULT 1,
  venue qtailane_venue,
  venue_contract_id TEXT,
  market_price FLOAT,
  resolved_at TIMESTAMPTZ,
  resolution_outcome TEXT CHECK (resolution_outcome IN ('YES','NO','AMBIGUOUS')),
  resolution_evidence TEXT,
  lineage_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_posterior_update TIMESTAMPTZ,
  last_evidence_at TIMESTAMPTZ,
  CONSTRAINT chk_uncertainty_band CHECK (uncertainty_band_lo <= uncertainty_band_hi),
  CONSTRAINT chk_uncertainty_contains_posterior CHECK (uncertainty_band_lo <= current_posterior AND current_posterior <= uncertainty_band_hi)
);
CREATE INDEX idx_qtailane_prob_obj_state ON qtailane_probability_objects(action_state);
CREATE INDEX idx_qtailane_prob_obj_active ON qtailane_probability_objects(action_state) WHERE action_state IN ('MONITORING','ACTIVE_TRADING','POSITION_LONG','POSITION_SHORT');
CREATE INDEX idx_qtailane_prob_obj_unresolved ON qtailane_probability_objects(created_at DESC) WHERE resolved_at IS NULL;

-- 5. CLAIM CLUSTERS (evidence lineage)
CREATE TABLE qtailane_claim_clusters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  probability_object_id UUID NOT NULL REFERENCES qtailane_probability_objects(id) ON DELETE CASCADE,
  source_class qtailane_source_class NOT NULL,
  evidence_items JSONB NOT NULL DEFAULT '[]',
  item_count INTEGER NOT NULL DEFAULT 0 CHECK (item_count >= 0),
  independence_score FLOAT CHECK (independence_score >= 0 AND independence_score <= 1),
  source_ancestry JSONB,
  is_independent BOOLEAN NOT NULL DEFAULT false,
  likelihood_ratio FLOAT,
  lr_estimation_method TEXT,
  lr_confidence FLOAT CHECK (lr_confidence >= 0 AND lr_confidence <= 1),
  regime_tag_id UUID REFERENCES qtailane_regime_states(id),
  narrative_stress_at_ingestion FLOAT,
  prior_before_update FLOAT CHECK (prior_before_update >= 0 AND prior_before_update <= 1),
  posterior_after_update FLOAT CHECK (posterior_after_update >= 0 AND posterior_after_update <= 1),
  cluster_hash TEXT,
  model_version_id UUID REFERENCES qtailane_model_registry(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_qtailane_claims_prob_obj ON qtailane_claim_clusters(probability_object_id);
CREATE INDEX idx_qtailane_claims_created ON qtailane_claim_clusters(created_at DESC);

-- 6. POSITIONS
CREATE TABLE qtailane_positions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  probability_object_id UUID REFERENCES qtailane_probability_objects(id),
  venue qtailane_venue NOT NULL,
  venue_deal_id TEXT,
  instrument TEXT NOT NULL,
  direction qtailane_direction NOT NULL,
  size FLOAT NOT NULL CHECK (size > 0),
  entry_price FLOAT NOT NULL,
  current_price FLOAT,
  kelly_fraction_used FLOAT CHECK (kelly_fraction_used >= 0 AND kelly_fraction_used <= 1),
  ev_real_at_entry FLOAT,
  sigma_model_at_entry FLOAT,
  sigma_exec_at_entry FLOAT,
  unrealised_pnl FLOAT DEFAULT 0,
  realised_pnl FLOAT DEFAULT 0,
  fees_total FLOAT DEFAULT 0,
  slippage_total FLOAT DEFAULT 0,
  is_open BOOLEAN NOT NULL DEFAULT true,
  is_frozen BOOLEAN NOT NULL DEFAULT false,
  frozen_by_cb qtailane_cb_type,
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  last_price_update TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_qtailane_positions_open ON qtailane_positions(is_open) WHERE is_open = true;
CREATE INDEX idx_qtailane_positions_instrument ON qtailane_positions(instrument);

-- 7. TRADES (immutable financial records)
CREATE TABLE qtailane_trades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  position_id UUID NOT NULL REFERENCES qtailane_positions(id),
  probability_object_id UUID REFERENCES qtailane_probability_objects(id),
  venue qtailane_venue NOT NULL,
  instrument TEXT NOT NULL,
  direction qtailane_direction NOT NULL,
  order_type qtailane_order_type NOT NULL,
  requested_size FLOAT NOT NULL,
  filled_size FLOAT NOT NULL,
  requested_price FLOAT,
  fill_price FLOAT NOT NULL,
  slippage FLOAT DEFAULT 0,
  latency_ms INTEGER,
  impact_cost_estimate FLOAT DEFAULT 0,
  fees FLOAT DEFAULT 0,
  gross_pnl FLOAT DEFAULT 0,
  net_pnl FLOAT DEFAULT 0,
  ev_real_at_trade FLOAT,
  kelly_fraction_at_trade FLOAT,
  regime_tag_id UUID REFERENCES qtailane_regime_states(id),
  model_version_id UUID REFERENCES qtailane_model_registry(id),
  venue_order_id TEXT,
  venue_deal_ref TEXT,
  executed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_qtailane_trades_position ON qtailane_trades(position_id);
CREATE INDEX idx_qtailane_trades_executed ON qtailane_trades(executed_at DESC);

-- 8. MARKET DATA (90-day rolling retention)
CREATE TABLE qtailane_market_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue qtailane_venue NOT NULL,
  instrument TEXT NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  open_price FLOAT,
  high_price FLOAT,
  low_price FLOAT,
  close_price FLOAT NOT NULL,
  volume FLOAT,
  bid FLOAT,
  ask FLOAT,
  spread FLOAT,
  depth_bid FLOAT,
  depth_ask FLOAT,
  timeframe TEXT NOT NULL DEFAULT '1m',
  is_live BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_qtailane_mktdata_lookup ON qtailane_market_data(venue, instrument, timestamp DESC);

-- 9. CIRCUIT BREAKERS
CREATE TABLE qtailane_circuit_breakers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cb_type qtailane_cb_type NOT NULL,
  status qtailane_cb_status NOT NULL DEFAULT 'INACTIVE',
  trigger_value FLOAT,
  trigger_threshold FLOAT,
  trigger_description TEXT NOT NULL,
  affected_scope TEXT,
  activated_at TIMESTAMPTZ,
  activated_by TEXT NOT NULL DEFAULT 'SYSTEM',
  deactivated_at TIMESTAMPTZ,
  deactivated_by TEXT,
  resumption_condition TEXT,
  resumption_evidence TEXT,
  waiting_period_hours INTEGER,
  owner_approval BOOLEAN DEFAULT false,
  principal_approval BOOLEAN DEFAULT false,
  incident_report TEXT,
  root_cause TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_qtailane_cb_active ON qtailane_circuit_breakers(status) WHERE status = 'ACTIVE';

-- 10. KL-DIVERGENCE LOG
CREATE TABLE qtailane_kl_divergence_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_a_id UUID REFERENCES qtailane_probability_objects(id),
  market_b_id UUID REFERENCES qtailane_probability_objects(id),
  market_a_label TEXT NOT NULL,
  market_b_label TEXT NOT NULL,
  relationship_type TEXT NOT NULL,
  distribution_a FLOAT[] NOT NULL,
  distribution_b FLOAT[] NOT NULL,
  kl_divergence FLOAT NOT NULL,
  expected_kl_range_lo FLOAT,
  expected_kl_range_hi FLOAT,
  is_alert BOOLEAN NOT NULL DEFAULT false,
  alert_threshold FLOAT,
  action_taken TEXT,
  scanned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_qtailane_kl_alerts ON qtailane_kl_divergence_log(is_alert) WHERE is_alert = true;

-- 11. BACKTEST RESULTS
CREATE TABLE qtailane_backtest_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  model_version_id UUID NOT NULL REFERENCES qtailane_model_registry(id),
  test_type TEXT NOT NULL,
  date_range_from TIMESTAMPTZ NOT NULL,
  date_range_to TIMESTAMPTZ NOT NULL,
  brier_score FLOAT,
  brier_reliability FLOAT,
  brier_resolution FLOAT,
  sharpe_ratio FLOAT,
  max_drawdown FLOAT,
  total_return FLOAT,
  win_rate FLOAT,
  category_metrics JSONB,
  regime_metrics JSONB,
  monte_carlo_runs INTEGER,
  mc_mean_return FLOAT,
  mc_std_return FLOAT,
  mc_5th_percentile FLOAT,
  mc_95th_percentile FLOAT,
  production_brier FLOAT,
  brier_delta FLOAT,
  ev_real_delta FLOAT,
  raw_results JSONB,
  notes TEXT,
  passed BOOLEAN,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_qtailane_backtest_model ON qtailane_backtest_results(model_version_id);

-- 12. AUDIT LOG (immutable — INV E-01)
CREATE TABLE qtailane_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action TEXT NOT NULL,
  action_category TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'INFO',
  actor_type TEXT NOT NULL,
  actor_id TEXT NOT NULL,
  target_type TEXT,
  target_id UUID,
  detail JSONB NOT NULL DEFAULT '{}',
  previous_hash TEXT,
  entry_hash TEXT,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_qtailane_audit_occurred ON qtailane_audit_log(occurred_at DESC);
CREATE INDEX idx_qtailane_audit_severity ON qtailane_audit_log(severity) WHERE severity IN ('ERROR','CRITICAL');

