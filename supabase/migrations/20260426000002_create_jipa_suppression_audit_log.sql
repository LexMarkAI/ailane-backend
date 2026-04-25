-- Append-only audit log of every state change on jipa_suppression_feed.
-- Required for LAE-001 release artefact integrity: enables point-in-time
-- queries answering "what was the suppression state at time T?"
-- Governing: AILANE-SPEC-JIPA-GRD-001 v1.2 §22; AILANE-DPIA-ESTATE-001
-- Addendum v1.3 §4.1; AMD-092 DA-04 v1.3.
-- Brief: AILANE-CC-BRIEF-DA-04-001 v1.3 §3.5

CREATE TABLE IF NOT EXISTS public.jipa_suppression_audit_log (
  audit_id           bigserial PRIMARY KEY,
  audit_timestamp    timestamptz NOT NULL DEFAULT now(),
  audit_operation    text NOT NULL CHECK (audit_operation IN ('INSERT', 'UPDATE', 'DELETE')),
  audit_actor        text,                          -- 'director' | 'edge_function' | 'system' | 'cc_synthetic_test'

  -- Snapshot of the row state AFTER the operation (or BEFORE for DELETE).
  -- No FK to jipa_suppression_feed.id so audit entries outlive any future row deletion.
  feed_id            uuid NOT NULL,
  request_ref        text NOT NULL,
  subject_hash       text NOT NULL,
  request_type       text NOT NULL,
  request_scope      text NOT NULL,
  specific_class     text,
  verified           boolean NOT NULL,
  suppression_active boolean NOT NULL,
  suppression_scope  jsonb,
  suppression_from   timestamptz,
  suppression_until  timestamptz,

  -- Diff metadata
  changed_columns    text[],                        -- which columns changed (UPDATE only)
  change_reason      text                           -- optional human-readable note
);

-- RLS: no direct user access; only service-role and trigger-driven inserts
ALTER TABLE public.jipa_suppression_audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "no_direct_access_audit" ON public.jipa_suppression_audit_log FOR ALL USING (false);

-- Indexes for point-in-time and per-subject queries
CREATE INDEX idx_jipa_audit_subject_hash_time
  ON public.jipa_suppression_audit_log (subject_hash, audit_timestamp DESC);
CREATE INDEX idx_jipa_audit_feed_id
  ON public.jipa_suppression_audit_log (feed_id, audit_timestamp DESC);
CREATE INDEX idx_jipa_audit_timestamp
  ON public.jipa_suppression_audit_log (audit_timestamp DESC);

-- Trigger function to capture every change on jipa_suppression_feed
CREATE OR REPLACE FUNCTION public.log_jipa_suppression_change()
RETURNS TRIGGER AS $$
DECLARE
  v_changed text[];
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.jipa_suppression_audit_log (
      audit_operation, feed_id, request_ref, subject_hash, request_type,
      request_scope, specific_class, verified, suppression_active,
      suppression_scope, suppression_from, suppression_until
    ) VALUES (
      'INSERT', NEW.id, NEW.request_ref, NEW.subject_hash, NEW.request_type,
      NEW.request_scope, NEW.specific_class, NEW.verified, NEW.suppression_active,
      NEW.suppression_scope, NEW.suppression_from, NEW.suppression_until
    );
    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    -- Compute changed columns (key state-relevant fields only)
    v_changed := ARRAY[]::text[];
    IF NEW.verified IS DISTINCT FROM OLD.verified THEN
      v_changed := array_append(v_changed, 'verified');
    END IF;
    IF NEW.suppression_active IS DISTINCT FROM OLD.suppression_active THEN
      v_changed := array_append(v_changed, 'suppression_active');
    END IF;
    IF NEW.suppression_scope IS DISTINCT FROM OLD.suppression_scope THEN
      v_changed := array_append(v_changed, 'suppression_scope');
    END IF;
    IF NEW.suppression_from IS DISTINCT FROM OLD.suppression_from THEN
      v_changed := array_append(v_changed, 'suppression_from');
    END IF;
    IF NEW.suppression_until IS DISTINCT FROM OLD.suppression_until THEN
      v_changed := array_append(v_changed, 'suppression_until');
    END IF;
    IF NEW.closure_reason IS DISTINCT FROM OLD.closure_reason THEN
      v_changed := array_append(v_changed, 'closure_reason');
    END IF;

    INSERT INTO public.jipa_suppression_audit_log (
      audit_operation, feed_id, request_ref, subject_hash, request_type,
      request_scope, specific_class, verified, suppression_active,
      suppression_scope, suppression_from, suppression_until,
      changed_columns
    ) VALUES (
      'UPDATE', NEW.id, NEW.request_ref, NEW.subject_hash, NEW.request_type,
      NEW.request_scope, NEW.specific_class, NEW.verified, NEW.suppression_active,
      NEW.suppression_scope, NEW.suppression_from, NEW.suppression_until,
      v_changed
    );
    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.jipa_suppression_audit_log (
      audit_operation, feed_id, request_ref, subject_hash, request_type,
      request_scope, specific_class, verified, suppression_active,
      suppression_scope, suppression_from, suppression_until
    ) VALUES (
      'DELETE', OLD.id, OLD.request_ref, OLD.subject_hash, OLD.request_type,
      OLD.request_scope, OLD.specific_class, OLD.verified, OLD.suppression_active,
      OLD.suppression_scope, OLD.suppression_from, OLD.suppression_until
    );
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger fires AFTER each operation so the row state is final
CREATE TRIGGER trg_jipa_suppression_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.jipa_suppression_feed
  FOR EACH ROW EXECUTE FUNCTION public.log_jipa_suppression_change();

COMMENT ON TABLE public.jipa_suppression_audit_log IS 'Append-only audit log of state changes on jipa_suppression_feed. Required for LAE-001 release artefact integrity. Retention: 7 years minimum (tax/audit baseline). Created by AMD-092 DA-04 v1.3.';
