-- Migration: 20260310033201_klac_001_projects_and_session_context
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: klac_001_projects_and_session_context


-- ============================================================
-- KLAC-001 — TABLES 3 & 4
-- kl_projects + kl_session_context
-- ============================================================

CREATE TABLE IF NOT EXISTS public.kl_projects (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name                text        NOT NULL,
  description         text,
  sector_tag          text,
  pinned_instruments  uuid[]      NOT NULL DEFAULT '{}',
  status              text        NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived','deleted')),
  session_count       integer     NOT NULL DEFAULT 0,
  last_session_at     timestamptz,
  summary_narrative   text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  deleted_at          timestamptz
);

ALTER TABLE public.kl_projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_projects_owner_select"
  ON public.kl_projects FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "kl_projects_owner_insert"
  ON public.kl_projects FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "kl_projects_owner_update"
  ON public.kl_projects FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "kl_projects_owner_soft_delete"
  ON public.kl_projects FOR DELETE
  USING (auth.uid() = user_id AND status = 'active');

-- ----

CREATE TABLE IF NOT EXISTS public.kl_session_context (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id         uuid        NOT NULL REFERENCES public.kl_sessions(id) ON DELETE CASCADE,
  project_id         uuid        REFERENCES public.kl_projects(id) ON DELETE SET NULL,
  user_id            uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message_role       text        NOT NULL CHECK (message_role IN ('user','assistant','system')),
  message_content    text        NOT NULL,
  instruments_cited  uuid[]      NOT NULL DEFAULT '{}',
  sequence           integer     NOT NULL,
  status             text        NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived')),
  created_at         timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.kl_session_context ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_session_context_owner_select"
  ON public.kl_session_context FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "kl_session_context_service_insert"
  ON public.kl_session_context FOR INSERT
  WITH CHECK (true); -- service role via Edge Functions

CREATE INDEX IF NOT EXISTS idx_kl_projects_user_id ON public.kl_projects(user_id);
CREATE INDEX IF NOT EXISTS idx_kl_projects_status ON public.kl_projects(status);
CREATE INDEX IF NOT EXISTS idx_kl_session_context_session_id ON public.kl_session_context(session_id);
CREATE INDEX IF NOT EXISTS idx_kl_session_context_project_id ON public.kl_session_context(project_id);
CREATE INDEX IF NOT EXISTS idx_kl_session_context_user_id ON public.kl_session_context(user_id);

