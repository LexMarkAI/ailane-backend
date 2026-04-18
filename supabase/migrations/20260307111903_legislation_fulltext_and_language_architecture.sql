-- Migration: 20260307111903_legislation_fulltext_and_language_architecture
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: legislation_fulltext_and_language_architecture


-- ═══════════════════════════════════════════════════════════════════════════
-- AILANE MIGRATION: legislation_fulltext + language architecture
-- AILANE-SPEC-LANG-001 v1.0
-- Date: 2026-03-07
-- Author: Ailane Index Committee
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. SUPPORTED LANGUAGES REFERENCE TABLE ───────────────────────────────
CREATE TABLE IF NOT EXISTS supported_languages (
  code              TEXT PRIMARY KEY,
  name_native       TEXT NOT NULL,
  name_english      TEXT NOT NULL,
  territory_codes   TEXT[]      DEFAULT '{}',
  active            BOOLEAN     DEFAULT FALSE,
  ui_available      BOOLEAN     DEFAULT FALSE,
  statute_available BOOLEAN     DEFAULT FALSE,
  rtl               BOOLEAN     DEFAULT FALSE,
  sort_order        INTEGER     DEFAULT 99,
  added_at          TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE supported_languages IS
  'Master language registry. Controls which languages are active across UI, statute pipeline, and client toggles. Add new territories here — no schema changes required.';

INSERT INTO supported_languages
  (code, name_native, name_english, territory_codes, active, ui_available, statute_available, sort_order)
VALUES
  ('en', 'English',  'English',          ARRAY['GB','Wales','Scotland','Ireland'], TRUE,  TRUE,  TRUE,  1),
  ('cy', 'Cymraeg',  'Welsh',            ARRAY['Wales'],                           TRUE,  TRUE,  TRUE,  2),
  ('ga', 'Gaeilge',  'Irish',            ARRAY['Ireland'],                         FALSE, FALSE, FALSE, 3),
  ('gd', 'Gàidhlig', 'Scottish Gaelic',  ARRAY['Scotland'],                        FALSE, FALSE, FALSE, 4),
  ('fr', 'Français', 'French',           ARRAY[]::TEXT[],                          FALSE, FALSE, FALSE, 10),
  ('de', 'Deutsch',  'German',           ARRAY[]::TEXT[],                          FALSE, FALSE, FALSE, 11)
ON CONFLICT (code) DO NOTHING;

-- ── 2. LEGISLATION FULLTEXT TABLE ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS legislation_fulltext (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Link to master library record
  legislation_id      UUID        NOT NULL
    REFERENCES legislation_library(id) ON DELETE CASCADE,

  -- Language
  language_code       TEXT        NOT NULL
    REFERENCES supported_languages(code),

  -- Source provenance
  fetch_source        TEXT        NOT NULL
    CHECK (fetch_source IN (
      'legislation_gov_uk_official',
      'ai_generated',
      'manual_verified',
      'third_party_licensed'
    )),
  fetch_url           TEXT,
  fetched_at          TIMESTAMPTZ,

  -- Content
  structured_xml      TEXT,
  html_rendered       TEXT,
  plain_text          TEXT,
  markdown_text       TEXT,

  -- Metrics
  word_count          INTEGER,
  section_count       INTEGER,
  schedule_count      INTEGER,
  amendment_count     INTEGER,

  -- Quality
  verified            BOOLEAN     DEFAULT FALSE,
  verified_by         TEXT,
  verified_at         TIMESTAMPTZ,
  quality_notes       TEXT,

  -- Translation metadata
  translation_model   TEXT,
  translation_batch   TEXT,
  translation_notice  TEXT,

  -- Tier access gate
  tier_access         TEXT        DEFAULT 'governance'
    CHECK (tier_access IN ('all','governance','institutional')),

  -- Timestamps
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW(),

  -- One record per instrument per language
  UNIQUE (legislation_id, language_code)
);

COMMENT ON TABLE legislation_fulltext IS
  'Full statutory text per instrument per language. Tier-gated via get_fulltext_for_org RPC. Strictly separated from legislation_library summary fields.';

COMMENT ON COLUMN legislation_fulltext.fetch_source IS
  'Provenance hierarchy: legislation_gov_uk_official > manual_verified > ai_generated > third_party_licensed';

COMMENT ON COLUMN legislation_fulltext.tier_access IS
  'Minimum tier required to access this record. governance = Governance + Institutional. institutional = Institutional only.';

-- ── 3. INDEXES ────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_fulltext_legislation_id
  ON legislation_fulltext (legislation_id);

CREATE INDEX IF NOT EXISTS idx_fulltext_language_code
  ON legislation_fulltext (language_code);

CREATE INDEX IF NOT EXISTS idx_fulltext_fetch_source
  ON legislation_fulltext (fetch_source);

CREATE INDEX IF NOT EXISTS idx_fulltext_verified
  ON legislation_fulltext (verified);

CREATE INDEX IF NOT EXISTS idx_fulltext_plain_search
  ON legislation_fulltext
  USING gin(to_tsvector('english', COALESCE(plain_text, '')));

-- ── 4. ORGANISATIONS — extend for language architecture ───────────────────
ALTER TABLE organisations
  ADD COLUMN IF NOT EXISTS enabled_languages  TEXT[]  DEFAULT ARRAY['en'],
  ADD COLUMN IF NOT EXISTS territory_codes    TEXT[]  DEFAULT ARRAY['GB'];

COMMENT ON COLUMN organisations.enabled_languages IS
  'Languages this org has access to. Controls toggle visibility and fulltext RPC gate. Populated from active_jurisdictions on onboarding.';

COMMENT ON COLUMN organisations.territory_codes IS
  'Active territory codes for this org. Drives jurisdiction-aware instrument filtering. Mirrors active_jurisdictions.';

-- Backfill existing Welsh demo org
UPDATE organisations
SET
  enabled_languages = ARRAY['en','cy'],
  territory_codes   = ARRAY['GB','Wales']
WHERE id = 'de000001-0000-4000-8000-000000000001';

-- ── 5. RPC: get_fulltext_for_org ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_fulltext_for_org(
  p_org_id         UUID,
  p_legislation_id UUID,
  p_language_code  TEXT DEFAULT 'en'
)
RETURNS TABLE (
  id                UUID,
  legislation_id    UUID,
  language_code     TEXT,
  fetch_source      TEXT,
  html_rendered     TEXT,
  plain_text        TEXT,
  word_count        INTEGER,
  section_count     INTEGER,
  verified          BOOLEAN,
  translation_notice TEXT,
  tier_access       TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    ft.id,
    ft.legislation_id,
    ft.language_code,
    ft.fetch_source,
    ft.html_rendered,
    ft.plain_text,
    ft.word_count,
    ft.section_count,
    ft.verified,
    ft.translation_notice,
    ft.tier_access
  FROM legislation_fulltext ft
  JOIN organisations o ON o.id = p_org_id
  WHERE ft.legislation_id = p_legislation_id
    AND ft.language_code  = p_language_code
    AND (
      ft.tier_access = 'all'
      OR (ft.tier_access = 'governance'
          AND o.tier IN ('governance','institutional'))
      OR (ft.tier_access = 'institutional'
          AND o.tier = 'institutional')
    )
    AND p_language_code = ANY(o.enabled_languages)
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION get_fulltext_for_org TO authenticated, service_role;

-- ── 6. RPC: get_available_languages ──────────────────────────────────────
CREATE OR REPLACE FUNCTION get_available_languages(p_org_id UUID)
RETURNS TABLE (
  code          TEXT,
  name_native   TEXT,
  name_english  TEXT,
  ui_available  BOOLEAN,
  statute_count BIGINT,
  enabled       BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    sl.code,
    sl.name_native,
    sl.name_english,
    sl.ui_available,
    COUNT(ft.id)                        AS statute_count,
    (sl.code = ANY(o.enabled_languages)) AS enabled
  FROM supported_languages sl
  JOIN organisations o ON o.id = p_org_id
  LEFT JOIN legislation_fulltext ft ON ft.language_code = sl.code
  WHERE sl.active = TRUE
  GROUP BY
    sl.code, sl.name_native, sl.name_english,
    sl.ui_available, sl.sort_order,
    o.enabled_languages
  ORDER BY sl.sort_order;
$$;

GRANT EXECUTE ON FUNCTION get_available_languages TO authenticated, service_role;

-- ── 7. RPC: get_fulltext_availability ────────────────────────────────────
-- Returns which languages have fulltext for a given instrument
CREATE OR REPLACE FUNCTION get_fulltext_availability(p_legislation_id UUID)
RETURNS TABLE (
  language_code  TEXT,
  name_native    TEXT,
  fetch_source   TEXT,
  verified       BOOLEAN,
  word_count     INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    ft.language_code,
    sl.name_native,
    ft.fetch_source,
    ft.verified,
    ft.word_count
  FROM legislation_fulltext ft
  JOIN supported_languages sl ON sl.code = ft.language_code
  WHERE ft.legislation_id = p_legislation_id
  ORDER BY sl.sort_order;
$$;

GRANT EXECUTE ON FUNCTION get_fulltext_availability TO authenticated, service_role;

