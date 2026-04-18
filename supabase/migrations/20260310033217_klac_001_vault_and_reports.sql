-- Migration: 20260310033217_klac_001_vault_and_reports
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: klac_001_vault_and_reports


-- ============================================================
-- KLAC-001 — TABLES 5, 6 & 7
-- kl_vault_documents + kl_vault_document_text + kl_report_history
-- ============================================================

CREATE TABLE IF NOT EXISTS public.kl_vault_documents (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id          uuid        REFERENCES public.kl_projects(id) ON DELETE SET NULL,
  filename            text        NOT NULL,
  storage_path        text        NOT NULL,
  file_size_bytes     integer     NOT NULL,
  mime_type           text        NOT NULL,
  extraction_status   text        NOT NULL DEFAULT 'pending' CHECK (extraction_status IN ('pending','extracted','failed')),
  instruments_mapped  uuid[]      NOT NULL DEFAULT '{}',
  analysis_status     text        NOT NULL DEFAULT 'pending' CHECK (analysis_status IN ('pending','analysed','error')),
  session_only        boolean     NOT NULL DEFAULT false,
  expires_at          timestamptz,
  deleted_at          timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.kl_vault_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_vault_documents_owner_select"
  ON public.kl_vault_documents FOR SELECT
  USING (auth.uid() = user_id AND deleted_at IS NULL);

CREATE POLICY "kl_vault_documents_owner_insert"
  ON public.kl_vault_documents FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "kl_vault_documents_owner_update"
  ON public.kl_vault_documents FOR UPDATE
  USING (auth.uid() = user_id);

-- ----

CREATE TABLE IF NOT EXISTS public.kl_vault_document_text (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id     uuid        NOT NULL UNIQUE REFERENCES public.kl_vault_documents(id) ON DELETE CASCADE,
  extracted_text  text        NOT NULL,
  char_count      integer     NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.kl_vault_document_text ENABLE ROW LEVEL SECURITY;

-- Service role only for insert/delete; users read via join through vault_documents RLS
CREATE POLICY "kl_vault_document_text_owner_select"
  ON public.kl_vault_document_text FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.kl_vault_documents d
      WHERE d.id = document_id AND d.user_id = auth.uid()
    )
  );

-- ----

CREATE TABLE IF NOT EXISTS public.kl_report_history (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id           uuid        REFERENCES public.kl_sessions(id) ON DELETE SET NULL,
  project_id           uuid        REFERENCES public.kl_projects(id) ON DELETE SET NULL,
  report_type          text        NOT NULL CHECK (report_type IN ('transcript','session_advisory','project_summary')),
  storage_path         text,
  generation_status    text        NOT NULL DEFAULT 'pending' CHECK (generation_status IN ('pending','generating','complete','failed')),
  stripe_charge_id     text,
  included_in_plan     boolean     NOT NULL DEFAULT false,
  emailed_at           timestamptz,
  expires_at           timestamptz NOT NULL,
  created_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.kl_report_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_report_history_owner_select"
  ON public.kl_report_history FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "kl_report_history_service_insert"
  ON public.kl_report_history FOR INSERT
  WITH CHECK (true); -- service role via Edge Functions

-- Indexes
CREATE INDEX IF NOT EXISTS idx_kl_vault_documents_user_id ON public.kl_vault_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_kl_vault_documents_project_id ON public.kl_vault_documents(project_id);
CREATE INDEX IF NOT EXISTS idx_kl_vault_documents_session_only ON public.kl_vault_documents(session_only);
CREATE INDEX IF NOT EXISTS idx_kl_vault_documents_expires_at ON public.kl_vault_documents(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_kl_report_history_user_id ON public.kl_report_history(user_id);
CREATE INDEX IF NOT EXISTS idx_kl_report_history_project_id ON public.kl_report_history(project_id);

