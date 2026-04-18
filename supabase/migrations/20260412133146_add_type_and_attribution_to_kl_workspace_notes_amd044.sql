-- Migration: 20260412133146_add_type_and_attribution_to_kl_workspace_notes_amd044
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_type_and_attribution_to_kl_workspace_notes_amd044


-- AMD-044 (KLUI-001-AM-001 §2.1) — Add note type classification and source attribution
-- Supports unified Saved Items panel: notes, clips, and saved Eileen responses in one table

ALTER TABLE public.kl_workspace_notes
ADD COLUMN IF NOT EXISTS note_type text NOT NULL DEFAULT 'note';

ALTER TABLE public.kl_workspace_notes
ADD COLUMN IF NOT EXISTS source_attribution text;

-- CHECK constraint for note_type values
ALTER TABLE public.kl_workspace_notes
ADD CONSTRAINT kl_workspace_notes_type_check
CHECK (note_type IN ('note', 'clip', 'eileen_response'));

-- Index on note_type for filtered queries (Saved Items panel filters by type)
CREATE INDEX IF NOT EXISTS idx_kl_workspace_notes_type
ON public.kl_workspace_notes (user_id, note_type);

-- Comment for documentation
COMMENT ON COLUMN public.kl_workspace_notes.note_type IS 'AMD-044: note = manual research note, clip = saved snippet from conversation/research, eileen_response = saved Eileen output';
COMMENT ON COLUMN public.kl_workspace_notes.source_attribution IS 'AMD-044: Source attribution text e.g. "[Eileen — 12 Apr 2026 14:32] What are my obligations under TUPE?" or "ERA 1996 s.86 — Notice periods"';

