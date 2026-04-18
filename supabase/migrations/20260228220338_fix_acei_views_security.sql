-- Migration: 20260228220338_fix_acei_views_security
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_acei_views_security


-- Fix security definer views: set to SECURITY INVOKER
ALTER VIEW public.v_evi_weekly SET (security_invoker = on);
ALTER VIEW public.v_eii_weekly SET (security_invoker = on);
ALTER VIEW public.v_sci_weekly SET (security_invoker = on);
ALTER VIEW public.v_impact_defaults SET (security_invoker = on);

-- Fix function search_path: pin to public schema
ALTER FUNCTION public.compute_acei_scores SET search_path = public;
ALTER FUNCTION public.write_acei_weekly_scores SET search_path = public;

