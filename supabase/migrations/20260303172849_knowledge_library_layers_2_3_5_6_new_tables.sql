-- Migration: 20260303172849_knowledge_library_layers_2_3_5_6_new_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: knowledge_library_layers_2_3_5_6_new_tables


-- ═══════════════════════════════════════════════════════════════
-- LAYERS 2, 3, 5, 6 + KEYWORDS: NEW TABLES
-- All jurisdiction FKs reference jurisdictions(code) text PK
-- ═══════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── LAYER 2: REGULATORY SOURCE REGISTRY ─────────────────────
CREATE TABLE IF NOT EXISTS regulatory_sources (
    id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    jurisdiction_code text NOT NULL REFERENCES jurisdictions(code),
    name            text NOT NULL,
    source_key      text NOT NULL UNIQUE,
    api_base_url    text,
    api_type        text NOT NULL CHECK (api_type IN ('atom_feed', 'rest_json', 'sparql', 'html_scrape', 'rss', 'api_graphql', 'bulk_download')),
    auth_method     text NOT NULL DEFAULT 'none' CHECK (auth_method IN ('none', 'api_key', 'oauth2', 'basic_auth')),
    licence         text,
    instrument_types text[] NOT NULL DEFAULT '{}',
    scrape_schedule text,
    health_status   text NOT NULL DEFAULT 'unknown' CHECK (health_status IN ('healthy', 'degraded', 'offline', 'unknown', 'deprecated')),
    last_scraped_at timestamptz,
    priority_rank   integer NOT NULL DEFAULT 1,
    notes           text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE regulatory_sources IS 'Layer 2: Registry of all authoritative regulatory data sources globally. CCI Art. V §5.1.1 (Tier P public-observable data).';

CREATE INDEX IF NOT EXISTS idx_regsources_jurisdiction ON regulatory_sources(jurisdiction_code);
CREATE INDEX IF NOT EXISTS idx_regsources_health ON regulatory_sources(health_status);

-- ─── LAYER 3: UNIVERSAL INSTRUMENT TAXONOMY ──────────────────
CREATE TABLE IF NOT EXISTS instrument_types (
    id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    universal_type  text NOT NULL CHECK (universal_type IN (
        'primary_legislation', 'secondary_legislation', 'binding_code',
        'regulatory_guidance', 'enforcement_notice', 'case_law',
        'international_treaty', 'eu_directive', 'eu_regulation'
    )),
    local_name      text NOT NULL,
    jurisdiction_code text NOT NULL REFERENCES jurisdictions(code),
    rce_type        integer NOT NULL CHECK (rce_type BETWEEN 1 AND 3),
    sci_default     integer NOT NULL DEFAULT 2 CHECK (sci_default BETWEEN 1 AND 5),
    description     text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE(local_name, jurisdiction_code)
);

COMMENT ON TABLE instrument_types IS 'Layer 3: Universal instrument taxonomy. RRI Art. II §2.3 (RCE Types 1-3).';

CREATE INDEX IF NOT EXISTS idx_insttypes_jurisdiction ON instrument_types(jurisdiction_code);
CREATE INDEX IF NOT EXISTS idx_insttypes_universal ON instrument_types(universal_type);

-- ─── LAYER 5: TERRITORIAL REACH (Many-to-Many) ──────────────
CREATE TABLE IF NOT EXISTS instrument_jurisdictions (
    id                  uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    instrument_id       uuid NOT NULL REFERENCES legislation_library(id) ON DELETE CASCADE,
    jurisdiction_code   text NOT NULL REFERENCES jurisdictions(code),
    reach_type          text NOT NULL CHECK (reach_type IN ('home', 'transposition', 'extraterritorial', 'mutual_recognition', 'commencement', 'adequacy')),
    effective_date      date,
    local_implementation text,
    commencement_status text DEFAULT 'fully_commenced' CHECK (commencement_status IN ('fully_commenced', 'partially_commenced', 'pending', 'not_commenced')),
    created_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE(instrument_id, jurisdiction_code, reach_type)
);

COMMENT ON TABLE instrument_jurisdictions IS 'Layer 5: Many-to-many territorial reach. ACEI Art. VIII §8.2 (multi-jurisdiction filtering).';

CREATE INDEX IF NOT EXISTS idx_instjur_instrument ON instrument_jurisdictions(instrument_id);
CREATE INDEX IF NOT EXISTS idx_instjur_jurisdiction ON instrument_jurisdictions(jurisdiction_code);
CREATE INDEX IF NOT EXISTS idx_instjur_status ON instrument_jurisdictions(commencement_status);

-- ─── LAYER 6: REGULATORY BODY REGISTRY ───────────────────────
CREATE TABLE IF NOT EXISTS regulatory_bodies (
    id                  uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                text NOT NULL,
    abbreviation        text,
    jurisdiction_code   text NOT NULL REFERENCES jurisdictions(code),
    acei_categories     integer[] NOT NULL DEFAULT '{}',
    website_url         text,
    enforcement_powers  text,
    feeds_eii           boolean NOT NULL DEFAULT false,
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE regulatory_bodies IS 'Layer 6: Enforcement and regulatory bodies feeding ACEI EII sub-index.';

CREATE INDEX IF NOT EXISTS idx_regbodies_jurisdiction ON regulatory_bodies(jurisdiction_code);
CREATE INDEX IF NOT EXISTS idx_regbodies_eii ON regulatory_bodies(feeds_eii) WHERE feeds_eii = true;

-- ─── SUPPORTING: LEGISLATION CATEGORY KEYWORDS ───────────────
CREATE TABLE IF NOT EXISTS legislation_category_keywords (
    id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    keyword     text NOT NULL,
    acei_category_number integer NOT NULL,
    acei_category_key text NOT NULL,
    weight      numeric(3,2) NOT NULL DEFAULT 1.00,
    UNIQUE(keyword, acei_category_number)
);

COMMENT ON TABLE legislation_category_keywords IS 'Keyword-to-ACEI-category mapping for automated instrument classification. Universal across jurisdictions.';

