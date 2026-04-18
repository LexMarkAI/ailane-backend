-- AILANE-CC-BRIEF-EILEEN-NEXUS-002-PART-A §2.1 lint hardening patch
-- Remediates two advisor findings against the §2.1 views:
--   (1) security_definer_view (ERROR) on public.vw_eileen_nexus_intel
--       — recreate with security_invoker = true so RLS on underlying tables
--         is enforced against the querying role (not view owner).
--   (2) materialized_view_in_api (WARN x3) — the three MVs are selectable
--       via PostgREST by anon/authenticated. Revoke public API exposure;
--       the Edge Function uses service_role which bypasses these revokes.
-- Applied 2026-04-18 under Chairman Path A deploy.
-- ===========================================================================

-- 1. Recreate umbrella view with security_invoker semantics.
DROP VIEW IF EXISTS public.vw_eileen_nexus_intel;

CREATE VIEW public.vw_eileen_nexus_intel
WITH (security_invoker = true) AS
SELECT
  ( SELECT jsonb_agg(to_jsonb(c) - 'snapshot_at' ORDER BY c.id)
      FROM public.vw_eileen_nexus_intel_categories c )       AS categories,
  ( SELECT COALESCE(jsonb_agg(to_jsonb(i) - 'snapshot_at'), '[]'::jsonb)
      FROM public.vw_eileen_nexus_intel_instruments i )      AS instruments,
  ( SELECT COALESCE(jsonb_agg(to_jsonb(r) - 'snapshot_at'), '[]'::jsonb)
      FROM public.vw_eileen_nexus_intel_relationships r )    AS relationships,
  now()                                                      AS snapshot_at;

COMMENT ON VIEW public.vw_eileen_nexus_intel IS
  'Umbrella view composing the three Nexus MVs into Art. 13.1 JSON shape. '
  'eileen-landing-intel v3 selects from this view via service_role. '
  'security_invoker = true enforces RLS on underlying tables against the '
  'querying role. anon/authenticated are revoked below.';

-- 2. Revoke PostgREST exposure on all three MVs and the umbrella view.
REVOKE ALL ON public.vw_eileen_nexus_intel_categories    FROM anon, authenticated;
REVOKE ALL ON public.vw_eileen_nexus_intel_instruments   FROM anon, authenticated;
REVOKE ALL ON public.vw_eileen_nexus_intel_relationships FROM anon, authenticated;
REVOKE ALL ON public.vw_eileen_nexus_intel               FROM anon, authenticated;

-- 3. Explicit grant to service_role (belt-and-braces; service_role has
--    superuser-like access by default in Supabase, but we assert it here
--    so future role changes don't silently break the Edge Function).
GRANT SELECT ON public.vw_eileen_nexus_intel_categories    TO service_role;
GRANT SELECT ON public.vw_eileen_nexus_intel_instruments   TO service_role;
GRANT SELECT ON public.vw_eileen_nexus_intel_relationships TO service_role;
GRANT SELECT ON public.vw_eileen_nexus_intel               TO service_role;
