-- Migration: 20260307045253_jurisdiction_layer_architecture
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: jurisdiction_layer_architecture


-- ── Step 1: Legislation Library — jurisdiction & language fields ──────────────
ALTER TABLE legislation_library
  ADD COLUMN IF NOT EXISTS jurisdiction_codes     TEXT[]  DEFAULT ARRAY['GB'],
  ADD COLUMN IF NOT EXISTS welsh_available        BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS title_cy               TEXT,
  ADD COLUMN IF NOT EXISTS summary_cy             TEXT,
  ADD COLUMN IF NOT EXISTS obligations_cy         TEXT,
  ADD COLUMN IF NOT EXISTS key_provisions_cy      TEXT,
  ADD COLUMN IF NOT EXISTS translation_method     TEXT    -- 'official_bilingual' | 'ai_assisted' | null
    CHECK (translation_method IN ('official_bilingual', 'ai_assisted'));

-- Index for fast jurisdiction filtering
CREATE INDEX IF NOT EXISTS idx_legislation_library_jurisdiction_codes
  ON legislation_library USING GIN (jurisdiction_codes);

-- ── Step 2: Organisations — active jurisdictions & language preference ────────
ALTER TABLE organisations
  ADD COLUMN IF NOT EXISTS active_jurisdictions   TEXT[]  DEFAULT ARRAY['GB'],
  ADD COLUMN IF NOT EXISTS preferred_language     TEXT    DEFAULT 'en'
    CHECK (preferred_language IN ('en', 'cy', 'ga', 'gd'));

CREATE INDEX IF NOT EXISTS idx_organisations_active_jurisdictions
  ON organisations USING GIN (active_jurisdictions);

-- ── Step 3: Mark all existing instruments as GB jurisdiction ──────────────────
UPDATE legislation_library
SET jurisdiction_codes = ARRAY['GB']
WHERE jurisdiction_codes IS NULL OR jurisdiction_codes = '{}';

-- ── Step 4: RPC for jurisdiction-aware knowledge library query ────────────────
CREATE OR REPLACE FUNCTION get_legislation_for_org(p_org_id UUID)
RETURNS TABLE (
  id                    UUID,
  legislation_ref       TEXT,
  short_title           TEXT,
  title_cy              TEXT,
  legislation_type      TEXT,
  lifecycle_stage       TEXT,
  summary               TEXT,
  summary_cy            TEXT,
  obligations_summary   TEXT,
  obligations_cy        TEXT,
  key_provisions        TEXT,
  key_provisions_cy     TEXT,
  acei_categories       TEXT[],
  primary_acei_category TEXT,
  tier_access           TEXT,
  jurisdiction_codes    TEXT[],
  welsh_available       BOOLEAN,
  translation_method    TEXT,
  legislation_gov_url   TEXT,
  sci_significance      NUMERIC,
  tags                  TEXT[]
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    ll.id,
    ll.legislation_ref,
    ll.short_title,
    ll.title_cy,
    ll.legislation_type,
    ll.lifecycle_stage,
    ll.summary,
    ll.summary_cy,
    ll.obligations_summary,
    ll.obligations_cy,
    ll.key_provisions,
    ll.key_provisions_cy,
    ll.acei_categories,
    ll.primary_acei_category,
    ll.tier_access,
    ll.jurisdiction_codes,
    ll.welsh_available,
    ll.translation_method,
    ll.legislation_gov_url,
    ll.sci_significance,
    ll.tags
  FROM legislation_library ll
  JOIN organisations o ON o.id = p_org_id
  WHERE ll.jurisdiction_codes && o.active_jurisdictions
  ORDER BY
    -- Welsh-specific instruments float to top for Welsh orgs
    CASE WHEN 'Wales' = ANY(ll.jurisdiction_codes) 
         AND 'Wales' = ANY(o.active_jurisdictions) THEN 0 ELSE 1 END,
    ll.sci_significance DESC NULLS LAST;
$$;

GRANT EXECUTE ON FUNCTION get_legislation_for_org TO authenticated, service_role;

COMMENT ON COLUMN legislation_library.jurisdiction_codes IS
  'Territories where this instrument applies. GB=all UK, Wales=Wales-specific, Scotland=Scotland-specific etc.';
COMMENT ON COLUMN organisations.active_jurisdictions IS
  'Jurisdiction layers active for this organisation. Controls Knowledge Library visibility.';
COMMENT ON COLUMN organisations.preferred_language IS
  'UI language preference. en=English, cy=Welsh (Cymraeg), ga=Irish, gd=Scottish Gaelic.';

