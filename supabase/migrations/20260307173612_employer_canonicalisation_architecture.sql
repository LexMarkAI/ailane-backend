-- Migration: 20260307173612_employer_canonicalisation_architecture
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: employer_canonicalisation_architecture


-- ── Employer Canonicalisation Architecture ────────────────────────────────
-- Adds canonical deduplication layer to employer_master.
-- One canonical record per CH number (is_canonical=TRUE, ch_registered_name set).
-- All name variants link back via canonical_employer_id.
-- Existing tribunal decision FKs are untouched.

-- 1. Add is_canonical flag
ALTER TABLE employer_master
  ADD COLUMN IF NOT EXISTS is_canonical BOOLEAN NOT NULL DEFAULT TRUE;

-- 2. Add self-referential FK for variant → canonical linkage
ALTER TABLE employer_master
  ADD COLUMN IF NOT EXISTS canonical_employer_id UUID REFERENCES employer_master(id) ON DELETE SET NULL;

-- 3. Add official CH registered name (distinct from raw tribunal name)
ALTER TABLE employer_master
  ADD COLUMN IF NOT EXISTS ch_registered_name TEXT;

-- 4. Index for fast canonical lookups
CREATE INDEX IF NOT EXISTS idx_employer_master_canonical_id
  ON employer_master(canonical_employer_id)
  WHERE canonical_employer_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_employer_master_is_canonical
  ON employer_master(is_canonical)
  WHERE is_canonical = TRUE;

CREATE INDEX IF NOT EXISTS idx_employer_master_ch_number_canonical
  ON employer_master(companies_house_number)
  WHERE companies_house_number IS NOT NULL AND is_canonical = TRUE;

-- 5. Canonical employers view — single record per CH number + all unmatched
CREATE OR REPLACE VIEW canonical_employers AS
SELECT
  em.*,
  -- Count of variant names pointing to this canonical
  (
    SELECT COUNT(*) FROM employer_master v
    WHERE v.canonical_employer_id = em.id
  ) AS variant_count
FROM employer_master em
WHERE em.is_canonical = TRUE;

-- 6. Function: resolve canonical employer for any employer_master id
--    Returns the canonical record's id (or the id itself if already canonical)
CREATE OR REPLACE FUNCTION resolve_canonical_employer(p_employer_id UUID)
RETURNS UUID
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(
    (SELECT canonical_employer_id FROM employer_master WHERE id = p_employer_id),
    p_employer_id
  );
$$;

-- 7. Function: get all tribunal name variants for a canonical employer
CREATE OR REPLACE FUNCTION get_employer_variants(p_canonical_id UUID)
RETURNS TABLE(
  id UUID,
  raw_name TEXT,
  ch_fetch_status TEXT,
  is_canonical BOOLEAN
)
LANGUAGE sql STABLE
AS $$
  -- The canonical itself
  SELECT id, raw_name, ch_fetch_status, is_canonical
  FROM employer_master
  WHERE id = p_canonical_id
  UNION ALL
  -- All variants pointing to it
  SELECT id, raw_name, ch_fetch_status, is_canonical
  FROM employer_master
  WHERE canonical_employer_id = p_canonical_id;
$$;

COMMENT ON COLUMN employer_master.is_canonical IS
  'TRUE = authoritative record for this CH number. FALSE = tribunal name variant linking to canonical.';
COMMENT ON COLUMN employer_master.canonical_employer_id IS
  'For variant records: points to the canonical employer_master row for this CH number. NULL on canonical records.';
COMMENT ON COLUMN employer_master.ch_registered_name IS
  'Official Companies House registered name. Populated on canonical records only.';
COMMENT ON VIEW canonical_employers IS
  'One row per verified employer. Excludes name variants (is_canonical=FALSE). Includes all unmatched employers.';

