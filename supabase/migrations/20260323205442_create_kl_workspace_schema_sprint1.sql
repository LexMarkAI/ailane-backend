-- Migration: 20260323205442_create_kl_workspace_schema_sprint1
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_kl_workspace_schema_sprint1


-- ============================================================================
-- MIGRATION: create_kl_workspace_schema_sprint1
-- SPECIFICATION: AILANE-SPEC-KLWS-001 §3.3 + AILANE-SPEC-KLUI-001 §3.1, §3.2
-- AMENDMENT: AMD-030 (KLWS-001), AMD-031 (KLUI-001)
-- SPRINT: 1 of 6 — Knowledge Library Workspace Foundation
-- DATE: 2026-03-23
-- ============================================================================

-- ============================================================================
-- TABLE 1: kl_user_preferences
-- Purpose: Panel state persistence, drawer width, layout mode, shortcuts config
-- Per KLUI-001 §2.2: drawer state persisted to DB for cross-session durability
-- ============================================================================
CREATE TABLE public.kl_user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
  -- Stores: panel_rail_state, active_panels, drawer_width, push_overlay_mode,
  -- layout_mode, keyboard_shortcuts_enabled, panel_arrangement, theme_overrides
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

COMMENT ON TABLE public.kl_user_preferences IS 'KLUI-001 §2.2 — Panel system preferences, drawer state, layout configuration. One row per user. Cross-session persistence for PPS.';
COMMENT ON COLUMN public.kl_user_preferences.preferences IS 'JSONB: panel_rail_state (expanded|collapsed), active_panels (UUID[]), drawer_width (320-600), push_overlay_mode (push|overlay), layout_mode (single|split|grid), keyboard_shortcuts_enabled (bool), panel_arrangement (ordered UUID[])';

-- ============================================================================
-- TABLE 2: kl_workspace_projects
-- Purpose: Logical grouping container for notes, documents, chat sessions, plans
-- Per KLWS-001 §3.3: projects organise workspace content by compliance activity
-- ============================================================================
CREATE TABLE public.kl_workspace_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  org_id UUID REFERENCES public.organisations(id),
  name TEXT NOT NULL,
  description TEXT,
  project_type TEXT NOT NULL DEFAULT 'general'
    CHECK (project_type IN ('research', 'contract_plan', 'policy_review', 'general')),
  visibility TEXT NOT NULL DEFAULT 'personal'
    CHECK (visibility IN ('personal', 'org_shared', 'org_required')),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'archived')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.kl_workspace_projects IS 'KLWS-001 §3.3 — Workspace project containers. Group notes, documents, chat sessions, and contract plans by compliance activity. Supports personal and org-shared visibility.';
COMMENT ON COLUMN public.kl_workspace_projects.project_type IS 'Governs available features: research (KL browse + notes), contract_plan (Planner panel, Governance+), policy_review (Vault + findings focus), general (all features)';
COMMENT ON COLUMN public.kl_workspace_projects.visibility IS 'personal = creator only. org_shared = visible to all org members (read). org_required = org-wide mandatory project (Governance+)';

-- ============================================================================
-- TABLE 3: kl_workspace_notes
-- Purpose: Rich-text notes with TipTap JSON storage, full-text search, pinning
-- Per KLUI-001 §3.2: auto-save, statutory ref tracking, project association
-- ============================================================================
CREATE TABLE public.kl_workspace_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.kl_workspace_projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT DEFAULT 'Untitled Note',
  content_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  content_plain TEXT DEFAULT '',
  statutory_refs TEXT[] DEFAULT '{}',
  pinned BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.kl_workspace_notes IS 'KLUI-001 §3.2 — Rich-text notes. TipTap ProseMirror JSON in content_json, plain text mirror in content_plain for full-text search. Auto-save debounced 3s.';
COMMENT ON COLUMN public.kl_workspace_notes.content_json IS 'TipTap 2.x ProseMirror document JSON. Includes heading, paragraph, bold, italic, underline, bulletList, orderedList, blockquote nodes.';
COMMENT ON COLUMN public.kl_workspace_notes.content_plain IS 'Plain text extraction of content_json for Postgres full-text search. Updated on every save.';
COMMENT ON COLUMN public.kl_workspace_notes.statutory_refs IS 'Array of statutory reference strings extracted from note content (e.g., ERA 1996 s.1, EqA 2010 s.13). Auto-populated by front-end on save.';

-- ============================================================================
-- ROW LEVEL SECURITY
-- Constitutional requirement: data isolation between users and organisations
-- ============================================================================

-- kl_user_preferences: strict user-only access
ALTER TABLE public.kl_user_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_prefs_user_all"
  ON public.kl_user_preferences FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- kl_workspace_projects: owner CRUD + org-shared read
ALTER TABLE public.kl_workspace_projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_projects_owner_all"
  ON public.kl_workspace_projects FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "kl_projects_org_shared_select"
  ON public.kl_workspace_projects FOR SELECT
  USING (
    visibility IN ('org_shared', 'org_required')
    AND org_id IS NOT NULL
    AND org_id = get_my_org_id()
  );

-- kl_workspace_notes: owner CRUD + org-shared-project read
ALTER TABLE public.kl_workspace_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_notes_owner_all"
  ON public.kl_workspace_notes FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "kl_notes_org_shared_select"
  ON public.kl_workspace_notes FOR SELECT
  USING (
    project_id IN (
      SELECT id FROM public.kl_workspace_projects
      WHERE visibility IN ('org_shared', 'org_required')
      AND org_id IS NOT NULL
      AND org_id = get_my_org_id()
    )
  );

-- ============================================================================
-- INDEXES
-- Performance: user lookups, org lookups, full-text search, project FK
-- ============================================================================
CREATE INDEX idx_kl_user_preferences_user ON public.kl_user_preferences(user_id);
CREATE INDEX idx_kl_workspace_projects_user ON public.kl_workspace_projects(user_id);
CREATE INDEX idx_kl_workspace_projects_org ON public.kl_workspace_projects(org_id) WHERE org_id IS NOT NULL;
CREATE INDEX idx_kl_workspace_projects_status ON public.kl_workspace_projects(status) WHERE status = 'active';
CREATE INDEX idx_kl_workspace_notes_project ON public.kl_workspace_notes(project_id);
CREATE INDEX idx_kl_workspace_notes_user ON public.kl_workspace_notes(user_id);
CREATE INDEX idx_kl_workspace_notes_pinned ON public.kl_workspace_notes(project_id, pinned) WHERE pinned = true;
CREATE INDEX idx_kl_workspace_notes_search ON public.kl_workspace_notes USING gin(to_tsvector('english', content_plain));

-- ============================================================================
-- UPDATED_AT TRIGGER
-- Automatic timestamp maintenance on row update
-- ============================================================================
CREATE OR REPLACE FUNCTION public.kl_workspace_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_kl_user_preferences_updated
  BEFORE UPDATE ON public.kl_user_preferences
  FOR EACH ROW EXECUTE FUNCTION public.kl_workspace_update_timestamp();

CREATE TRIGGER trg_kl_workspace_projects_updated
  BEFORE UPDATE ON public.kl_workspace_projects
  FOR EACH ROW EXECUTE FUNCTION public.kl_workspace_update_timestamp();

CREATE TRIGGER trg_kl_workspace_notes_updated
  BEFORE UPDATE ON public.kl_workspace_notes
  FOR EACH ROW EXECUTE FUNCTION public.kl_workspace_update_timestamp();

