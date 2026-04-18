-- Migration: 20260412191221_make_kl_workspace_notes_project_id_nullable
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: make_kl_workspace_notes_project_id_nullable


-- Fix: Allow notes to exist without a project (loose notes, quick saves from Eileen responses)
-- Root cause: Sprint D Save-to-Notes POSTs with project_id: null, violating NOT NULL constraint
-- This prevents ALL note creation from the MessageBubble Save button and NotesPanel New Note button

ALTER TABLE public.kl_workspace_notes
ALTER COLUMN project_id DROP NOT NULL;

COMMENT ON COLUMN public.kl_workspace_notes.project_id IS 'Nullable — notes can exist without a project (e.g. quick saves from Eileen responses). FK to kl_workspace_projects(id) when associated with a project.';

