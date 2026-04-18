-- Migration: 20260321020638_qtailane_stage3_evidence_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qtailane_stage3_evidence_tables


-- ============================================================
-- QTAILANE STAGE 3 — MIGRATION 1: EVIDENCE SOURCE TABLES
-- Authority: QTAILANE-BUILD-001 Stage 3 / QTAILANE-MTH-005 Ch.3
-- Purpose: Store, classify, and track independence of all
--          non-market evidence entering the platform.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. EVIDENCE SOURCE REGISTRY
-- Master catalogue of all evidence providers.
-- Each source has a trust profile and independence classification.
-- ────────────────────────────────────────────────────────────
CREATE TABLE qtailane_evidence_sources (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Identity
  source_name           TEXT NOT NULL,              -- 'Reuters', 'AP', 'Federal Reserve', 'Sentinel-2', etc.
  source_class          qtailane_source_class NOT NULL,
  source_type           TEXT NOT NULL,              -- 'wire_service', 'government', 'satellite', 'economic_data', 'social_media', 'aggregator'
  
  -- Trust profile (MTH-005 §3.1)
  trust_score           FLOAT NOT NULL DEFAULT 0.5 CHECK (trust_score >= 0 AND trust_score <= 1),
  trust_basis           TEXT,                       -- explanation of how trust score was determined
  historical_accuracy   FLOAT CHECK (historical_accuracy >= 0 AND historical_accuracy <= 1),
  known_biases          TEXT,                       -- documented biases or blind spots
  
  -- Independence mapping (BFC-01 protection)
  parent_source_id      UUID REFERENCES qtailane_evidence_sources(id), -- NULL = root/independent source
  independence_group    TEXT,                       -- sources in same group share ancestry
  is_primary            BOOLEAN NOT NULL DEFAULT false, -- true = original reporting; false = derivative
  
  -- Operational
  api_endpoint          TEXT,                       -- base URL for programmatic access
  auth_method           TEXT,                       -- 'api_key', 'oauth', 'public', 'scrape'
  rate_limit_per_min    INTEGER,
  polling_interval_sec  INTEGER DEFAULT 300,        -- default 5 minutes
  
  -- Licensing
  license_type          TEXT,                       -- 'public', 'api_terms', 'commercial', 'academic'
  retention_limit_days  INTEGER,                    -- max days we can store per license terms
  attribution_required  BOOLEAN NOT NULL DEFAULT false,
  
  -- Category coverage (which event categories this source is relevant for)
  covers_categories     qtailane_event_category[] NOT NULL DEFAULT '{}',
  covers_jurisdictions  TEXT[] NOT NULL DEFAULT '{}',
  
  -- State
  is_active             BOOLEAN NOT NULL DEFAULT true,
  last_ingestion_at     TIMESTAMPTZ,
  total_items_ingested  BIGINT NOT NULL DEFAULT 0,
  
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT uq_qtailane_evidence_source UNIQUE (source_name, source_class)
);

CREATE INDEX idx_qtailane_evsrc_class ON qtailane_evidence_sources(source_class);
CREATE INDEX idx_qtailane_evsrc_active ON qtailane_evidence_sources(is_active) WHERE is_active = true;
CREATE INDEX idx_qtailane_evsrc_primary ON qtailane_evidence_sources(is_primary) WHERE is_primary = true;
CREATE INDEX idx_qtailane_evsrc_group ON qtailane_evidence_sources(independence_group);

-- ────────────────────────────────────────────────────────────
-- 2. RAW EVIDENCE ITEMS
-- Individual evidence items as ingested. Each item is tagged
-- with source, class, and independence metadata BEFORE it
-- enters the inference pipeline (Stage 5).
-- ────────────────────────────────────────────────────────────
CREATE TABLE qtailane_evidence_items (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Source identity
  source_id             UUID NOT NULL REFERENCES qtailane_evidence_sources(id),
  source_class          qtailane_source_class NOT NULL,  -- denormalised for query speed
  source_item_id        TEXT,                       -- external ID from the source (article ID, filing number, etc.)
  
  -- Content
  title                 TEXT,
  content_summary       TEXT NOT NULL,              -- max 2000 chars — no raw licensed text stored
  content_hash          TEXT NOT NULL,              -- SHA-256 of original content for dedup
  content_language      TEXT DEFAULT 'en',
  
  -- Classification (pre-inference tagging)
  relevance_categories  qtailane_event_category[] NOT NULL DEFAULT '{}',
  relevance_jurisdictions TEXT[] NOT NULL DEFAULT '{}',
  relevance_score       FLOAT CHECK (relevance_score >= 0 AND relevance_score <= 1),
  
  -- Sentiment and narrative signal
  sentiment_score       FLOAT CHECK (sentiment_score >= -1 AND sentiment_score <= 1), -- -1 negative to +1 positive
  narrative_intensity   FLOAT CHECK (narrative_intensity >= 0 AND narrative_intensity <= 1),
  
  -- Independence tracking (BFC-01 — Source Ancestry Contamination)
  source_ancestry_chain TEXT[] NOT NULL DEFAULT '{}', -- lineage: [original_source, intermediary_1, ...]
  is_original_reporting BOOLEAN NOT NULL DEFAULT false,
  duplicate_of_id       UUID REFERENCES qtailane_evidence_items(id), -- if detected as duplicate
  
  -- Temporal
  published_at          TIMESTAMPTZ,                -- when the source published it
  ingested_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  -- Processing state
  processing_status     TEXT NOT NULL DEFAULT 'INGESTED'
                        CHECK (processing_status IN ('INGESTED','CLASSIFIED','CLUSTERED','PROCESSED','DISCARDED')),
  assigned_cluster_id   UUID,                       -- populated when grouped into a claim cluster (Stage 5)
  discarded_reason      TEXT,                       -- if status = DISCARDED, why
  
  -- Metadata
  raw_metadata          JSONB NOT NULL DEFAULT '{}', -- source-specific metadata (author, section, tags)
  
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_qtailane_evidence_source ON qtailane_evidence_items(source_id);
CREATE INDEX idx_qtailane_evidence_class ON qtailane_evidence_items(source_class);
CREATE INDEX idx_qtailane_evidence_status ON qtailane_evidence_items(processing_status);
CREATE INDEX idx_qtailane_evidence_ingested ON qtailane_evidence_items(ingested_at DESC);
CREATE INDEX idx_qtailane_evidence_published ON qtailane_evidence_items(published_at DESC);
CREATE INDEX idx_qtailane_evidence_hash ON qtailane_evidence_items(content_hash);
CREATE INDEX idx_qtailane_evidence_unprocessed ON qtailane_evidence_items(processing_status)
  WHERE processing_status IN ('INGESTED','CLASSIFIED');
CREATE INDEX idx_qtailane_evidence_categories ON qtailane_evidence_items USING GIN (relevance_categories);

-- ────────────────────────────────────────────────────────────
-- 3. SOURCE ANCESTRY MAP
-- Explicit graph of which sources derive from which.
-- Used by the independence verifier in Stage 5 to prevent
-- BFC-01 (Source Ancestry Contamination).
-- 5 news articles from the same Reuters wire = 1 evidence item.
-- ────────────────────────────────────────────────────────────
CREATE TABLE qtailane_source_ancestry (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  child_source_id       UUID NOT NULL REFERENCES qtailane_evidence_sources(id),
  parent_source_id      UUID NOT NULL REFERENCES qtailane_evidence_sources(id),
  
  relationship_type     TEXT NOT NULL CHECK (relationship_type IN (
    'DERIVES_FROM',       -- child re-reports parent's content
    'SYNDICATES',         -- child republishes parent verbatim
    'CITES',              -- child explicitly references parent
    'SHARES_ORIGIN',      -- both draw from same underlying source
    'TRANSLATES'          -- child is translation of parent
  )),
  
  confidence            FLOAT NOT NULL DEFAULT 0.8 CHECK (confidence >= 0 AND confidence <= 1),
  evidence_for_link     TEXT,                       -- why we believe this relationship exists
  
  -- If relationship is conditional on topic/event type
  conditional_on        TEXT,                       -- 'political_news', 'economic_data', etc. NULL = always
  
  is_active             BOOLEAN NOT NULL DEFAULT true,
  verified_at           TIMESTAMPTZ,
  verified_by           TEXT,
  
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT uq_qtailane_ancestry UNIQUE (child_source_id, parent_source_id, relationship_type),
  CONSTRAINT chk_no_self_ancestry CHECK (child_source_id != parent_source_id)
);

CREATE INDEX idx_qtailane_ancestry_child ON qtailane_source_ancestry(child_source_id);
CREATE INDEX idx_qtailane_ancestry_parent ON qtailane_source_ancestry(parent_source_id);

-- ────────────────────────────────────────────────────────────
-- 4. EVIDENCE CONNECTOR STATUS
-- Extends the connector_status pattern from Stage 2 for
-- evidence-specific connectors.
-- Reuses qtailane_connector_status with evidence-specific names.
-- ────────────────────────────────────────────────────────────

-- (No new table needed — we insert evidence connector rows into
--  qtailane_connector_status using venue = 'PAPER' as a
--  catch-all for non-venue connectors. But this is inelegant.
--  Better: add a connector_type column.)

-- Add connector_type to existing table to support evidence connectors
ALTER TABLE qtailane_connector_status 
  ADD COLUMN IF NOT EXISTS connector_type TEXT NOT NULL DEFAULT 'MARKET'
  CHECK (connector_type IN ('MARKET','EVIDENCE','SYSTEM'));

-- ────────────────────────────────────────────────────────────
-- 5. NARRATIVE STRESS AGGREGATOR TABLE
-- Feeds the NS dimension of the regime object (Stage 6).
-- Tracks rolling narrative intensity across all evidence sources.
-- ────────────────────────────────────────────────────────────
CREATE TABLE qtailane_narrative_stress_snapshots (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Scope
  category              qtailane_event_category,    -- NULL = global aggregate
  jurisdiction          TEXT,                       -- NULL = global
  
  -- Metrics
  narrative_stress      FLOAT NOT NULL CHECK (narrative_stress >= 0 AND narrative_stress <= 1),
  source_count          INTEGER NOT NULL,           -- how many sources contributed
  item_count            INTEGER NOT NULL,           -- total evidence items in window
  sentiment_divergence  FLOAT,                      -- std dev of sentiment across sources (high = polarised)
  volume_z_score        FLOAT,                      -- evidence volume vs 30-day rolling mean
  
  -- Window
  window_start          TIMESTAMPTZ NOT NULL,
  window_end            TIMESTAMPTZ NOT NULL,
  window_minutes        INTEGER NOT NULL DEFAULT 60,
  
  computed_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_qtailane_ns_computed ON qtailane_narrative_stress_snapshots(computed_at DESC);
CREATE INDEX idx_qtailane_ns_category ON qtailane_narrative_stress_snapshots(category);
CREATE INDEX idx_qtailane_ns_global ON qtailane_narrative_stress_snapshots(computed_at DESC) WHERE category IS NULL;

-- ────────────────────────────────────────────────────────────
-- RLS & TRIGGERS
-- ────────────────────────────────────────────────────────────
ALTER TABLE qtailane_evidence_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE qtailane_evidence_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE qtailane_source_ancestry ENABLE ROW LEVEL SECURITY;
ALTER TABLE qtailane_narrative_stress_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY qtailane_read_ev_sources ON qtailane_evidence_sources FOR SELECT TO authenticated USING (true);
CREATE POLICY qtailane_read_ev_items ON qtailane_evidence_items FOR SELECT TO authenticated USING (true);
CREATE POLICY qtailane_read_ancestry ON qtailane_source_ancestry FOR SELECT TO authenticated USING (true);
CREATE POLICY qtailane_read_ns_snapshots ON qtailane_narrative_stress_snapshots FOR SELECT TO authenticated USING (true);

CREATE TRIGGER trg_qtailane_evsrc_updated 
  BEFORE UPDATE ON qtailane_evidence_sources 
  FOR EACH ROW EXECUTE FUNCTION qtailane_set_updated_at();

