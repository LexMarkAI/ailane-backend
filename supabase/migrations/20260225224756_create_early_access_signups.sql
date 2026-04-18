-- Migration: 20260225224756_create_early_access_signups
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_early_access_signups


CREATE TABLE public.early_access_signups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  source text DEFAULT 'landing_page',
  utm_source text,
  utm_medium text,
  utm_campaign text,
  referrer text,
  ip_country text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Prevent duplicate signups
CREATE UNIQUE INDEX idx_early_access_email ON public.early_access_signups (lower(email));

-- Enable RLS
ALTER TABLE public.early_access_signups ENABLE ROW LEVEL SECURITY;

-- Allow anonymous inserts (the landing page form) but no reads
CREATE POLICY "Allow anonymous inserts" ON public.early_access_signups
  FOR INSERT TO anon WITH CHECK (true);

-- Only authenticated/service role can read
CREATE POLICY "Service role can read all" ON public.early_access_signups
  FOR SELECT TO authenticated USING (true);

COMMENT ON TABLE public.early_access_signups IS 'Landing page email capture — feeds sales pipeline';
