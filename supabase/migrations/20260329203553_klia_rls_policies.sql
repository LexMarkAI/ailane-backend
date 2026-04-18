-- Migration: 20260329203553_klia_rls_policies
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: klia_rls_policies


-- Enable RLS on all KLIA tables (zero unprotected tables policy)
ALTER TABLE public.kl_provisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_legislative_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_update_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_update_history ENABLE ROW LEVEL SECURITY;

-- kl_provisions: Read by all authenticated users (powers Eileen RAG)
-- Write by service_role only (ingestion pipeline)
CREATE POLICY "kl_provisions_read_authenticated"
    ON public.kl_provisions FOR SELECT
    TO authenticated
    USING (true);

-- kl_cases: Read by all authenticated users (powers Eileen RAG)
-- Write by service_role only
CREATE POLICY "kl_cases_read_authenticated"
    ON public.kl_cases FOR SELECT
    TO authenticated
    USING (true);

-- kl_legislative_alerts: Read by authenticated users (CEO Command Centre)
-- Write by service_role only (surveillance pipeline)
CREATE POLICY "kl_alerts_read_authenticated"
    ON public.kl_legislative_alerts FOR SELECT
    TO authenticated
    USING (true);

-- kl_update_drafts: Read by authenticated users (CEO ratification interface)
-- Write by service_role only (Eileen assessment pipeline)
CREATE POLICY "kl_drafts_read_authenticated"
    ON public.kl_update_drafts FOR SELECT
    TO authenticated
    USING (true);

-- kl_update_history: Read by authenticated users (audit trail)
-- Write by service_role only
CREATE POLICY "kl_history_read_authenticated"
    ON public.kl_update_history FOR SELECT
    TO authenticated
    USING (true);

