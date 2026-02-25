-- ============================================================
-- Ailane ACEI — Week 1 Enhanced Schema
-- Run against Supabase (PostgreSQL 15+)
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------
-- 1. Organizations
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS organizations (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name          TEXT NOT NULL,
    slug          TEXT UNIQUE NOT NULL,
    industry      TEXT,
    jurisdiction  TEXT DEFAULT 'US-FEDERAL',
    tier          TEXT DEFAULT 'free' CHECK (tier IN ('free', 'pro', 'enterprise')),
    created_at    TIMESTAMPTZ DEFAULT now(),
    updated_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_organizations_slug ON organizations(slug);

-- -----------------------------------------------------------
-- 2. ACEI Versions
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS acei_versions (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    version       TEXT NOT NULL UNIQUE,
    published_at  TIMESTAMPTZ DEFAULT now(),
    active        BOOLEAN DEFAULT false,
    changelog     TEXT,
    weights_json  JSONB,
    created_at    TIMESTAMPTZ DEFAULT now()
);

-- -----------------------------------------------------------
-- 3. ACEI Scores
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS acei_scores (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    version             TEXT NOT NULL,
    risk_category       TEXT NOT NULL CHECK (risk_category IN (
                            'regulatory', 'operational', 'financial',
                            'reputational', 'cyber', 'legal'
                        )),
    jurisdiction        TEXT NOT NULL,
    label               TEXT DEFAULT '',

    impact_score        NUMERIC(5,2) NOT NULL,
    likelihood_score    NUMERIC(5,2) NOT NULL,
    velocity_multiplier NUMERIC(5,3) NOT NULL,
    raw_score           NUMERIC(7,2) NOT NULL,
    adjusted_score      NUMERIC(7,2) NOT NULL,
    mitigation_credit   NUMERIC(5,4) DEFAULT 0,
    final_score         NUMERIC(6,2) NOT NULL,
    grade               CHAR(1) NOT NULL CHECK (grade IN ('A','B','C','D','F')),

    computed_at         TIMESTAMPTZ DEFAULT now(),
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_acei_scores_org     ON acei_scores(organization_id);
CREATE INDEX IF NOT EXISTS idx_acei_scores_grade   ON acei_scores(grade);
CREATE INDEX IF NOT EXISTS idx_acei_scores_computed ON acei_scores(computed_at DESC);

-- -----------------------------------------------------------
-- 4. Regulatory Updates  (fed by scrapers)
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS regulatory_updates (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title         TEXT NOT NULL,
    summary       TEXT,
    jurisdiction  TEXT NOT NULL,
    source        TEXT,
    source_url    TEXT,
    content_hash  TEXT UNIQUE,
    published_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reg_updates_hash   ON regulatory_updates(content_hash);
CREATE INDEX IF NOT EXISTS idx_reg_updates_source ON regulatory_updates(source);
CREATE INDEX IF NOT EXISTS idx_reg_updates_date   ON regulatory_updates(published_at DESC);

-- -----------------------------------------------------------
-- 5. Scraper Runs  (audit trail for scraper executions)
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS scraper_runs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source          TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running','success','error')),
    items_inserted  INTEGER DEFAULT 0,
    started_at      TIMESTAMPTZ DEFAULT now(),
    finished_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scraper_runs_source ON scraper_runs(source);

-- -----------------------------------------------------------
-- 6. Row-Level Security (RLS)
-- -----------------------------------------------------------
ALTER TABLE organizations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE acei_scores         ENABLE ROW LEVEL SECURITY;
ALTER TABLE regulatory_updates  ENABLE ROW LEVEL SECURITY;
ALTER TABLE scraper_runs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE acei_versions       ENABLE ROW LEVEL SECURITY;

-- Service-role bypass (backend can read/write everything)
CREATE POLICY "service_role_all" ON organizations      FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON acei_scores         FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON regulatory_updates  FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON scraper_runs        FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON acei_versions       FOR ALL USING (auth.role() = 'service_role');
