-- Migration: 20260308192145_cis_performance_conversions_audience
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: cis_performance_conversions_audience


-- ── TABLE 6: DAILY PERFORMANCE SNAPSHOTS ────────────────────
CREATE TABLE cis.performance_daily (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id         UUID NOT NULL REFERENCES cis.campaigns(id) ON DELETE CASCADE,
  ad_group_id         UUID REFERENCES cis.ad_groups(id) ON DELETE SET NULL,
  platform            TEXT NOT NULL CHECK (platform IN ('google', 'linkedin')),
  snapshot_date       DATE NOT NULL,
  impressions         BIGINT DEFAULT 0,
  clicks              BIGINT DEFAULT 0,
  conversions         NUMERIC(10,2) DEFAULT 0,
  cost_gbp            NUMERIC(10,2) DEFAULT 0,
  ctr                 NUMERIC(6,4),
  cpc_gbp             NUMERIC(10,4),
  cpa_gbp             NUMERIC(10,2),
  avg_position        NUMERIC(5,2),
  created_at          TIMESTAMPTZ DEFAULT now(),
  UNIQUE (campaign_id, ad_group_id, snapshot_date)
);

-- ── TABLE 7: CONVERSION EVENTS ───────────────────────────────
-- Attribution bridge: ad interaction → Ailane signup/upgrade
CREATE TABLE cis.conversions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id         UUID REFERENCES cis.campaigns(id) ON DELETE SET NULL,
  ad_group_id         UUID REFERENCES cis.ad_groups(id) ON DELETE SET NULL,
  keyword_id          UUID REFERENCES cis.keywords(id) ON DELETE SET NULL,
  platform            TEXT CHECK (platform IN ('google', 'linkedin', 'organic', 'direct', 'unknown')),
  conversion_type     TEXT NOT NULL CHECK (conversion_type IN ('signup', 'tier_upgrade', 'scan_purchase')),
  tier_converted_to   TEXT CHECK (tier_converted_to IN ('operational', 'governance', 'institutional', 'scan_19', 'scan_39')),
  revenue_gbp         NUMERIC(10,2),
  utm_source          TEXT,
  utm_medium          TEXT,
  utm_campaign        TEXT,
  utm_content         TEXT,
  utm_term            TEXT,
  supabase_user_id    UUID,
  attributed_at       TIMESTAMPTZ DEFAULT now(),
  attribution_window_days SMALLINT DEFAULT 30,
  confidence          TEXT CHECK (confidence IN ('direct', 'assisted', 'inferred')),
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- ── TABLE 8: AUDIENCE SEGMENTS (LinkedIn demographics) ───────
CREATE TABLE cis.audience_segments (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id         UUID NOT NULL REFERENCES cis.campaigns(id) ON DELETE CASCADE,
  snapshot_date       DATE NOT NULL,
  segment_type        TEXT NOT NULL CHECK (segment_type IN ('job_title', 'seniority', 'company_size', 'industry', 'geography', 'function')),
  segment_value       TEXT NOT NULL,
  impressions         BIGINT DEFAULT 0,
  clicks              BIGINT DEFAULT 0,
  ctr                 NUMERIC(6,4),
  conversions         NUMERIC(10,2) DEFAULT 0,
  cost_gbp            NUMERIC(10,2) DEFAULT 0,
  created_at          TIMESTAMPTZ DEFAULT now()
);

