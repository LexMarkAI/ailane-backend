-- Migration: 20260313233132_qai_003_finding_feedback_rls
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qai_003_finding_feedback_rls

ALTER TABLE public.finding_feedback ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'finding_feedback'
    AND policyname = 'finding_feedback_service_all'
  ) THEN
    CREATE POLICY "finding_feedback_service_all"
      ON public.finding_feedback
      FOR ALL
      USING (auth.role() = 'service_role');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'finding_feedback'
    AND policyname = 'finding_feedback_user_insert'
  ) THEN
    CREATE POLICY "finding_feedback_user_insert"
      ON public.finding_feedback
      FOR INSERT
      WITH CHECK (true);
  END IF;
END $$;
