-- Migration: 20260417001925_widen_jurisdiction_code_and_add_eat_content_hash_unique
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: widen_jurisdiction_code_and_add_eat_content_hash_unique


-- ──────────────────────────────────────────────────────────────────────
-- AILANE INTEL ESTATE — SCHEMA ALIGNMENT (17-Apr-2026)
-- ──────────────────────────────────────────────────────────────────────
-- Rationale:
--   1. jurisdiction_code was provisioned as VARCHAR(2) on 5 intel tables
--      (ISO 3166-1 alpha-2). The canonical Ailane jurisdiction code format
--      is 'GB-UK' (5 chars) to align with the enrichment estate's
--      GB-ENG / GB-SCT / GB-WLS / GB-NIR subdivision convention.
--      Widen to VARCHAR(10) for institutional consistency.
--
--   2. eat_case_law has UNIQUE(source_identifier) but no UNIQUE(content_hash).
--      All 5 peer tables use content_hash as the idempotent-upsert conflict
--      target. Add UNIQUE(content_hash) to eat_case_law to match the pattern
--      and unlock backfill via ON CONFLICT (content_hash).
--
-- ACEI authority: Art. XI (Data Governance) — estate-wide schema consistency.
-- Reversibility: both changes are non-destructive (widen only, add constraint only).
-- ──────────────────────────────────────────────────────────────────────

ALTER TABLE public.fos_firm_complaints       ALTER COLUMN jurisdiction_code TYPE VARCHAR(10);
ALTER TABLE public.fca_firm_complaints       ALTER COLUMN jurisdiction_code TYPE VARCHAR(10);
ALTER TABLE public.tpr_penalty_notices       ALTER COLUMN jurisdiction_code TYPE VARCHAR(10);
ALTER TABLE public.fca_enforcement_notices   ALTER COLUMN jurisdiction_code TYPE VARCHAR(10);
ALTER TABLE public.tpo_determinations        ALTER COLUMN jurisdiction_code TYPE VARCHAR(10);

ALTER TABLE public.eat_case_law
  ADD CONSTRAINT eat_case_law_hash_unique UNIQUE (content_hash);

COMMENT ON CONSTRAINT eat_case_law_hash_unique ON public.eat_case_law IS
  'Idempotent UPSERT target for scraper/backfill pipelines. Pattern-aligned with peer intel tables. ACEI Art. XI (Data Governance) — 17-Apr-2026.';

