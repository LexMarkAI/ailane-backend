-- AILANE-CC-BRIEF-EILEEN-NEXUS-002-PART-A §2.2
-- Schedule pg_cron refresh of the Nexus materialised views every 5 minutes.
-- Authority: AMD-058 Art. 13.4 (rendering implies sub-hour data freshness).
-- Depends on: §2.1 MVs (20260418120000), §2.1-patch grants (20260418120500).

-- pg_cron is already enabled in this project (see prior migrations); this is
-- a defensive no-op if so. No WITH SCHEMA clause — PG's IF NOT EXISTS accepts
-- the extension in whatever schema it was originally installed under.
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Idempotent: unschedule any prior jobs with the same names before scheduling.
DO $$
DECLARE
  jid bigint;
BEGIN
  SELECT jobid INTO jid FROM cron.job
    WHERE jobname = 'refresh-eileen-nexus-intel-categories';
  IF jid IS NOT NULL THEN PERFORM cron.unschedule(jid); END IF;

  SELECT jobid INTO jid FROM cron.job
    WHERE jobname = 'refresh-eileen-nexus-intel-relationships';
  IF jid IS NOT NULL THEN PERFORM cron.unschedule(jid); END IF;
END $$;

-- Every 5 minutes. CONCURRENTLY requires the unique indexes from §2.1.
SELECT cron.schedule(
  'refresh-eileen-nexus-intel-categories',
  '*/5 * * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY public.vw_eileen_nexus_intel_categories$$
);

SELECT cron.schedule(
  'refresh-eileen-nexus-intel-relationships',
  '*/5 * * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY public.vw_eileen_nexus_intel_relationships$$
);

-- vw_eileen_nexus_intel_instruments is a WHERE-false placeholder per §2.1 /
-- Chairman ruling item 2; refresh would be a no-op, so it is not scheduled
-- until the v4 brief replaces the placeholder with a live query.
