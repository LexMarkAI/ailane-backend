-- Migration: 20260308192131_cis_schema_and_campaigns
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: cis_schema_and_campaigns


-- ============================================================
-- AILANE CAMPAIGN INTELLIGENCE SYSTEM
-- AILANE-SPEC-CAMINT-001 v1.0
-- Phase 1: Schema + Core Tables
-- Strictly separated from all regulatory intelligence schemas
-- ============================================================

CREATE SCHEMA IF NOT EXISTS cis;

-- ── TABLE 1: CAMPAIGNS ───────────────────────────────────────
CREATE TABLE cis.campaigns (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform            TEXT NOT NULL CHECK (platform IN ('google', 'linkedin')),
  platform_id         TEXT NOT NULL,
  name                TEXT NOT NULL,
  status              TEXT NOT NULL CHECK (status IN ('active', 'paused', 'removed', 'draft')),
  objective           TEXT,
  daily_budget_gbp    NUMERIC(10,2),
  total_spend_gbp     NUMERIC(10,2) DEFAULT 0,
  campaign_type       TEXT,
  targeting_summary   JSONB,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

-- ── TABLE 2: AD GROUPS ───────────────────────────────────────
CREATE TABLE cis.ad_groups (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id         UUID NOT NULL REFERENCES cis.campaigns(id) ON DELETE CASCADE,
  platform_id         TEXT NOT NULL,
  name                TEXT NOT NULL,
  status              TEXT NOT NULL CHECK (status IN ('active', 'paused', 'removed')),
  targeting_params    JSONB,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

-- ── TABLE 3: KEYWORDS ────────────────────────────────────────
CREATE TABLE cis.keywords (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_group_id         UUID NOT NULL REFERENCES cis.ad_groups(id) ON DELETE CASCADE,
  campaign_id         UUID NOT NULL REFERENCES cis.campaigns(id) ON DELETE CASCADE,
  keyword_text        TEXT NOT NULL,
  match_type          TEXT NOT NULL CHECK (match_type IN ('exact', 'phrase', 'broad', 'negative')),
  status              TEXT NOT NULL CHECK (status IN ('active', 'paused', 'removed')),
  current_bid_gbp     NUMERIC(10,4),
  quality_score       SMALLINT CHECK (quality_score BETWEEN 1 AND 10),
  impressions         BIGINT DEFAULT 0,
  clicks              BIGINT DEFAULT 0,
  conversions         NUMERIC(10,2) DEFAULT 0,
  cost_gbp            NUMERIC(10,2) DEFAULT 0,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

-- ── TABLE 4: SEARCH TERMS ────────────────────────────────────
CREATE TABLE cis.search_terms (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id         UUID NOT NULL REFERENCES cis.campaigns(id) ON DELETE CASCADE,
  ad_group_id         UUID REFERENCES cis.ad_groups(id) ON DELETE SET NULL,
  keyword_id          UUID REFERENCES cis.keywords(id) ON DELETE SET NULL,
  search_term         TEXT NOT NULL,
  match_type          TEXT,
  impressions         BIGINT DEFAULT 0,
  clicks              BIGINT DEFAULT 0,
  conversions         NUMERIC(10,2) DEFAULT 0,
  cost_gbp            NUMERIC(10,2) DEFAULT 0,
  ctr                 NUMERIC(6,4),
  cpc_gbp             NUMERIC(10,4),
  recorded_date       DATE NOT NULL,
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- ── TABLE 5: AD COPY ─────────────────────────────────────────
CREATE TABLE cis.ad_copy (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id         UUID NOT NULL REFERENCES cis.campaigns(id) ON DELETE CASCADE,
  ad_group_id         UUID NOT NULL REFERENCES cis.ad_groups(id) ON DELETE CASCADE,
  platform_id         TEXT,
  headline_1          TEXT,
  headline_2          TEXT,
  headline_3          TEXT,
  description_1       TEXT,
  description_2       TEXT,
  status              TEXT NOT NULL CHECK (status IN ('active', 'paused', 'removed')),
  impressions         BIGINT DEFAULT 0,
  clicks              BIGINT DEFAULT 0,
  conversions         NUMERIC(10,2) DEFAULT 0,
  cost_gbp            NUMERIC(10,2) DEFAULT 0,
  ctr                 NUMERIC(6,4),
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

