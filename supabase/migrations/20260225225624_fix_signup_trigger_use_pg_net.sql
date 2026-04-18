-- Migration: 20260225225624_fix_signup_trigger_use_pg_net
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_signup_trigger_use_pg_net


-- Replace trigger function to use pg_net (which is installed) instead of http extension
CREATE OR REPLACE FUNCTION public.notify_new_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net, extensions
AS $$
DECLARE
  payload jsonb;
  request_id bigint;
BEGIN
  payload := jsonb_build_object(
    'type', 'INSERT',
    'table', 'early_access_signups',
    'record', jsonb_build_object(
      'id', NEW.id,
      'email', NEW.email,
      'source', NEW.source,
      'utm_source', NEW.utm_source,
      'utm_medium', NEW.utm_medium,
      'utm_campaign', NEW.utm_campaign,
      'referrer', NEW.referrer,
      'created_at', NEW.created_at
    )
  );

  SELECT net.http_post(
    url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/notify-signup'::text,
    body := payload,
    headers := '{"Content-Type": "application/json"}'::jsonb
  ) INTO request_id;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Signup notification failed: %', SQLERRM;
    RETURN NEW;
END;
$$;
