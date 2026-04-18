-- Migration: 20260409043129_enable_rls_intelligence_estate_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: enable_rls_intelligence_estate_tables


-- P0 SECURITY FIX: Enable RLS on all intelligence estate tables
-- Supabase alert 7 April 2026 — "Anyone with your project URL can read, edit, and delete all data"
-- These tables contain public intelligence data — read-only access for anon/authenticated
-- Write access restricted to service_role (which bypasses RLS by default)

-- 1. Enable RLS on all affected tables
ALTER TABLE public.eat_case_law ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.union_annual_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intelligence_source_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.welsh_public_sector_workforce ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ncsc_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hmrc_nmw_naming ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intl_cyber_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.govuk_policy_papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mi5_threat_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.npsa_guidance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nca_fraud_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_fraud_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_security_sweeps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.govuk_blog_content ENABLE ROW LEVEL SECURITY;

-- 2. Add read-only SELECT policies (public intelligence data)
CREATE POLICY "Public read access" ON public.eat_case_law FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.union_annual_data FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.intelligence_source_files FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.welsh_public_sector_workforce FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.ncsc_alerts FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.hmrc_nmw_naming FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.intl_cyber_alerts FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.govuk_policy_papers FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.mi5_threat_levels FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.npsa_guidance FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.nca_fraud_alerts FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.report_fraud_alerts FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.email_security_sweeps FOR SELECT USING (true);
CREATE POLICY "Public read access" ON public.govuk_blog_content FOR SELECT USING (true);

-- No INSERT/UPDATE/DELETE policies created — only service_role can write (bypasses RLS)
-- This means: anyone can READ public intelligence data, but only backend/Edge Functions can WRITE

