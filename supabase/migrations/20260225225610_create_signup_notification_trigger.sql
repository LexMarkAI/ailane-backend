-- Migration: 20260225225610_create_signup_notification_trigger
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_signup_notification_trigger


-- Trigger function: calls the notify-signup Edge Function via pg_net
CREATE OR REPLACE FUNCTION public.notify_new_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  payload jsonb;
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

  PERFORM extensions.http_post(
    url := 'https://cnbsxwtvazfvzmltkuvx.supabase.co/functions/v1/notify-signup',
    body := payload::text,
    content_type := 'application/json'
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Never block signups if notification fails
    RAISE WARNING 'Signup notification failed: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Fire on every insert
CREATE TRIGGER trg_notify_signup
  AFTER INSERT ON public.early_access_signups
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_new_signup();

COMMENT ON FUNCTION public.notify_new_signup IS 'Sends email notification to mark@ailane.ai via Edge Function on new signup';
