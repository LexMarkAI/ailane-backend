-- Migration: 20260323034256_kltr_add_anon_read_published_policy
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: kltr_add_anon_read_published_policy


-- ═══════════════════════════════════════════════════════════════
-- KLTR-001 — Add anon read access to published training resources
-- The training/index.html page is a PUBLIC conversion funnel.
-- Unauthenticated visitors must see the resource index (titles,
-- descriptions, categories, word counts). Full content_html is
-- included so authenticated users get inline reading, but the
-- public page shows previews only (first 200 chars stripped).
-- Constitutional separation: read-only, never modifies scores.
-- ═══════════════════════════════════════════════════════════════

CREATE POLICY "kl_tr_anon_read_published" ON public.kl_training_resources
    FOR SELECT TO anon
    USING (is_published = true);

