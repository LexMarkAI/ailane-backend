-- Create jipa_suppression_feed table to record subject-rights suppression requests
-- Governing spec: AILANE-SPEC-JIPA-GRD-001 v1.2 §22 Breach Response Protocol; AILANE-DPIA-ESTATE-001 Addendum v1.3 §4.1
-- Lawful basis: UK GDPR Article 17 (erasure); Article 21 (objection). Suppression is the operational mechanism for honouring these rights in JIPA output processing.
-- Brief: AILANE-CC-BRIEF-DA-04-001 v1.3 · DA-04 (AMD-092)

CREATE TABLE IF NOT EXISTS public.jipa_suppression_feed (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  -- Request identification
  request_ref     text NOT NULL UNIQUE,   -- human-readable reference e.g. DSR-2026-0001
  submitted_via   text NOT NULL CHECK (submitted_via IN ('email_privacy_inbox', 'webform', 'api', 'postal', 'ico_forwarded')),
  submitted_at    timestamptz NOT NULL,

  -- Data subject identification (minimum necessary)
  subject_hash    text NOT NULL,          -- hashed identifier (e.g. SHA-256 of normalised name + DOB) -- never the raw identifier
  subject_anonymised_id text,             -- if available from source tribunal record, the anonymised ID
  claim_reference text,                   -- tribunal case reference where applicable

  -- Request classification
  request_type    text NOT NULL CHECK (request_type IN ('erasure', 'objection', 'rectification', 'restriction', 'access')),
  request_scope   text NOT NULL CHECK (request_scope IN ('jipa_outputs_only', 'full_estate', 'specific_class')),
  specific_class  text CHECK (specific_class IS NULL OR specific_class IN ('A', 'B', 'C', 'D', 'E_T1', 'family_i')),

  -- Verification status (Director-reviewed)
  verified        boolean NOT NULL DEFAULT false,
  verified_by     text,                   -- who verified ('director' | 'deputised_reviewer')
  verified_at     timestamptz,
  verification_notes text,

  -- Suppression outcome
  suppression_active boolean NOT NULL DEFAULT false,  -- set true on Director verification
  suppression_scope  jsonb,                           -- structured scope (which classes, ALINs, cohorts to exclude)
  suppression_from   timestamptz,                     -- effective-from date
  suppression_until  timestamptz,                     -- NULL = indefinite

  -- Counterparty notification tracking
  notified_counterparties jsonb DEFAULT '[]'::jsonb,  -- array of {clid, notified_at, ack_received_at}
  notification_required_for_release uuid[],           -- JIPA output release IDs needing counterparty notification

  -- Audit
  source_request_metadata jsonb,          -- full intake payload for audit
  closure_reason  text,                   -- when suppression_active flipped false
  closed_at       timestamptz
);

-- RLS: no direct user access; only service-role via Edge Function
ALTER TABLE public.jipa_suppression_feed ENABLE ROW LEVEL SECURITY;
CREATE POLICY "no_direct_access" ON public.jipa_suppression_feed FOR ALL USING (false);

-- Indexes
CREATE INDEX idx_jipa_suppression_subject_hash ON public.jipa_suppression_feed (subject_hash);
CREATE INDEX idx_jipa_suppression_active ON public.jipa_suppression_feed (suppression_active) WHERE suppression_active = true;
CREATE INDEX idx_jipa_suppression_created_at ON public.jipa_suppression_feed (created_at DESC);

-- updated_at trigger (scoped to jipa_suppression_feed; no collision with set_updated_at* on other tables)
CREATE OR REPLACE FUNCTION public.set_updated_at_jipa_suppression()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER jipa_suppression_updated_at
  BEFORE UPDATE ON public.jipa_suppression_feed
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_jipa_suppression();

COMMENT ON TABLE public.jipa_suppression_feed IS 'Subject-rights suppression requests in respect of JIPA Outputs. Governing: AILANE-SPEC-JIPA-GRD-001 v1.2; AILANE-DPIA-ESTATE-001 Addendum v1.3 §4.1. Created by AMD-092 DA-04.';
