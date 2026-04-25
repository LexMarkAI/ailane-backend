// supabase/functions/jipa-suppression-handler/index.ts
// AILANE-CC-BRIEF-DA-04-001 v1.3 §4 + §7 follow-up
// AMD-092 DA-04 · JIPA Output Subject-Rights Suppression Handler
// Deploy: verify_jwt=false (external webhook from privacy@ailane.ai intake;
//         authenticated via shared-secret header per §4.2)
// Governing: AILANE-SPEC-JIPA-GRD-001 v1.2 §22; AILANE-DPIA-ESTATE-001
//            Addendum v1.3 §4.1
//
// v2 (§7 follow-up): structured logging refinement
//   - correlation_id generated per request, threaded through all log lines
//     and surfaced via X-Correlation-Id response header
//   - event_type taxonomy on every log line:
//       intake_received   — initial request entry
//       auth_failure      — shared-secret missing or mismatch
//       validation_failure — method/JSON/payload-shape rejection
//       intake_success    — 202 persisted
//       intake_duplicate  — 409 unique-constraint violation
//       intake_error      — 500 misconfig or DB failure
//   - every terminal log line carries the HTTP status returned
//   - request_ref logged once payload is parsed
//   - subject_hash only — raw identifiers (normalised_name, dob) never
//     reach any log line (already met by design; reaffirmed)

import { createClient } from 'npm:@supabase/supabase-js@2';

// --- Cold-start secret resolution ---------------------------------------

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const JIPA_PRIVACY_SHARED_SECRET = Deno.env.get('JIPA_PRIVACY_SHARED_SECRET');

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !JIPA_PRIVACY_SHARED_SECRET) {
  console.error('[jipa-suppression-handler] missing required secret(s) at cold start');
}

// --- Structured logging -------------------------------------------------

type EventType =
  | 'intake_received'
  | 'auth_failure'
  | 'validation_failure'
  | 'intake_success'
  | 'intake_duplicate'
  | 'intake_error';

function newCorrelationId(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return `corr-${Date.now().toString(16)}-${Math.random().toString(16).slice(2, 10)}`;
}

function logEvent(payload: Record<string, unknown>): void {
  console.log(JSON.stringify(payload));
}

// --- CORS ---------------------------------------------------------------

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Ailane-Privacy-Secret',
  'Access-Control-Expose-Headers': 'X-Correlation-Id',
  'Access-Control-Max-Age': '86400',
};

function jsonResponse(body: unknown, status: number, correlationId: string): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'X-Correlation-Id': correlationId,
      ...CORS_HEADERS,
    },
  });
}

// --- Payload schema + validator -----------------------------------------

type SubmittedVia =
  | 'email_privacy_inbox'
  | 'webform'
  | 'api'
  | 'postal'
  | 'ico_forwarded';

type RequestType =
  | 'erasure'
  | 'objection'
  | 'rectification'
  | 'restriction'
  | 'access';

type RequestScope = 'jipa_outputs_only' | 'full_estate' | 'specific_class';

type SpecificClass = 'A' | 'B' | 'C' | 'D' | 'E_T1' | 'family_i';

interface SubjectIdentification {
  normalised_name: string;
  dob: string;
  claim_reference?: string | null;
}

interface IntakePayload {
  request_ref: string;
  submitted_via: SubmittedVia;
  submitted_at: string;
  subject_identification: SubjectIdentification;
  request_type: RequestType;
  request_scope: RequestScope;
  specific_class?: SpecificClass | null;
  source_metadata?: Record<string, unknown>;
}

const SUBMITTED_VIA_SET = new Set<SubmittedVia>([
  'email_privacy_inbox', 'webform', 'api', 'postal', 'ico_forwarded',
]);
const REQUEST_TYPE_SET = new Set<RequestType>([
  'erasure', 'objection', 'rectification', 'restriction', 'access',
]);
const REQUEST_SCOPE_SET = new Set<RequestScope>([
  'jipa_outputs_only', 'full_estate', 'specific_class',
]);
const SPECIFIC_CLASS_SET = new Set<SpecificClass>([
  'A', 'B', 'C', 'D', 'E_T1', 'family_i',
]);

const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const ISO_DATETIME_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

type ValidationResult =
  | { ok: true; value: IntakePayload }
  | { ok: false; error: string };

function validatePayload(raw: unknown): ValidationResult {
  if (!isObject(raw)) return { ok: false, error: 'payload_not_object' };

  const request_ref = raw.request_ref;
  if (typeof request_ref !== 'string' || request_ref.length === 0 || request_ref.length > 128) {
    return { ok: false, error: 'invalid_request_ref' };
  }

  const submitted_via = raw.submitted_via;
  if (typeof submitted_via !== 'string' || !SUBMITTED_VIA_SET.has(submitted_via as SubmittedVia)) {
    return { ok: false, error: 'invalid_submitted_via' };
  }

  const submitted_at = raw.submitted_at;
  if (typeof submitted_at !== 'string' || !ISO_DATETIME_RE.test(submitted_at)) {
    return { ok: false, error: 'invalid_submitted_at' };
  }

  if (!isObject(raw.subject_identification)) {
    return { ok: false, error: 'invalid_subject_identification' };
  }
  const si = raw.subject_identification;
  if (typeof si.normalised_name !== 'string' || si.normalised_name.length === 0 || si.normalised_name.length > 512) {
    return { ok: false, error: 'invalid_normalised_name' };
  }
  if (typeof si.dob !== 'string' || !ISO_DATE_RE.test(si.dob)) {
    return { ok: false, error: 'invalid_dob' };
  }
  if (si.claim_reference !== undefined && si.claim_reference !== null && typeof si.claim_reference !== 'string') {
    return { ok: false, error: 'invalid_claim_reference' };
  }

  const request_type = raw.request_type;
  if (typeof request_type !== 'string' || !REQUEST_TYPE_SET.has(request_type as RequestType)) {
    return { ok: false, error: 'invalid_request_type' };
  }

  const request_scope = raw.request_scope;
  if (typeof request_scope !== 'string' || !REQUEST_SCOPE_SET.has(request_scope as RequestScope)) {
    return { ok: false, error: 'invalid_request_scope' };
  }

  let specific_class: SpecificClass | null = null;
  if (raw.specific_class !== undefined && raw.specific_class !== null) {
    if (typeof raw.specific_class !== 'string' || !SPECIFIC_CLASS_SET.has(raw.specific_class as SpecificClass)) {
      return { ok: false, error: 'invalid_specific_class' };
    }
    specific_class = raw.specific_class as SpecificClass;
  }

  if (request_scope === 'specific_class' && specific_class === null) {
    return { ok: false, error: 'specific_class_required_when_scope_is_specific_class' };
  }

  const source_metadata = raw.source_metadata;
  if (source_metadata !== undefined && !isObject(source_metadata)) {
    return { ok: false, error: 'invalid_source_metadata' };
  }

  return {
    ok: true,
    value: {
      request_ref,
      submitted_via: submitted_via as SubmittedVia,
      submitted_at,
      subject_identification: {
        normalised_name: si.normalised_name,
        dob: si.dob,
        claim_reference: (si.claim_reference as string | null | undefined) ?? null,
      },
      request_type: request_type as RequestType,
      request_scope: request_scope as RequestScope,
      specific_class,
      source_metadata: (source_metadata as Record<string, unknown> | undefined) ?? {},
    },
  };
}

// --- subject_hash -------------------------------------------------------

async function computeSubjectHash(normalisedName: string, dob: string): Promise<string> {
  const canonical = `${normalisedName.toLowerCase()}|${dob}`;
  const encoded = new TextEncoder().encode(canonical);
  const digest = await crypto.subtle.digest('SHA-256', encoded);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

// --- Constant-time secret comparison ------------------------------------

function secretsMatch(provided: string, expected: string): boolean {
  if (provided.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < provided.length; i++) {
    diff |= provided.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return diff === 0;
}

// --- Handler ------------------------------------------------------------

Deno.serve(async (req) => {
  // CORS preflight is unauthenticated and not logged (preflight noise).
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  const correlation_id = newCorrelationId();
  const t0 = Date.now();

  // -- intake_received --------------------------------------------------
  logEvent({
    event_type: 'intake_received' satisfies EventType,
    correlation_id,
    method: req.method,
    received_at: new Date(t0).toISOString(),
  });

  // Method check
  if (req.method !== 'POST') {
    logEvent({
      event_type: 'validation_failure' satisfies EventType,
      correlation_id,
      status: 405,
      reason: 'method_not_allowed',
      method: req.method,
    });
    return jsonResponse({ error: 'method_not_allowed' }, 405, correlation_id);
  }

  // Cold-start secret check
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !JIPA_PRIVACY_SHARED_SECRET) {
    const missing: string[] = [];
    if (!SUPABASE_URL) missing.push('SUPABASE_URL');
    if (!SUPABASE_SERVICE_ROLE_KEY) missing.push('SUPABASE_SERVICE_ROLE_KEY');
    if (!JIPA_PRIVACY_SHARED_SECRET) missing.push('JIPA_PRIVACY_SHARED_SECRET');
    logEvent({
      event_type: 'intake_error' satisfies EventType,
      correlation_id,
      status: 500,
      reason: 'missing_secrets',
      missing_secrets: missing,
    });
    return jsonResponse({ error: 'server_misconfigured' }, 500, correlation_id);
  }

  // Shared-secret auth (§4.2)
  const providedSecret = req.headers.get('X-Ailane-Privacy-Secret') ?? '';
  if (!providedSecret || !secretsMatch(providedSecret, JIPA_PRIVACY_SHARED_SECRET)) {
    logEvent({
      event_type: 'auth_failure' satisfies EventType,
      correlation_id,
      status: 401,
      reason: providedSecret ? 'shared_secret_mismatch' : 'shared_secret_missing',
    });
    return jsonResponse({ error: 'unauthorized' }, 401, correlation_id);
  }

  // Parse body
  let rawBody: unknown;
  try {
    rawBody = await req.json();
  } catch {
    logEvent({
      event_type: 'validation_failure' satisfies EventType,
      correlation_id,
      status: 400,
      reason: 'invalid_json',
    });
    return jsonResponse({ error: 'invalid_json' }, 400, correlation_id);
  }

  // request_ref isn't validated yet, but if it's a string we can echo it
  // into the validation_failure log so the caller's ticketing can correlate.
  const tentativeRequestRef = isObject(rawBody) && typeof rawBody.request_ref === 'string'
    ? rawBody.request_ref
    : null;

  const validated = validatePayload(rawBody);
  if (!validated.ok) {
    logEvent({
      event_type: 'validation_failure' satisfies EventType,
      correlation_id,
      status: 400,
      reason: validated.error,
      request_ref: tentativeRequestRef,
    });
    return jsonResponse({ error: 'invalid_payload', detail: validated.error }, 400, correlation_id);
  }
  const payload = validated.value;

  // Compute subject_hash. Raw identifiers never persist and never log.
  const subjectHash = await computeSubjectHash(
    payload.subject_identification.normalised_name,
    payload.subject_identification.dob,
  );

  const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const sourceMetadataSafe: Record<string, unknown> = { ...(payload.source_metadata ?? {}) };
  delete sourceMetadataSafe.normalised_name;
  delete sourceMetadataSafe.dob;
  delete sourceMetadataSafe.subject_identification;

  const { error: insertErr } = await sb
    .schema('public')
    .from('jipa_suppression_feed')
    .insert({
      request_ref: payload.request_ref,
      submitted_via: payload.submitted_via,
      submitted_at: payload.submitted_at,
      subject_hash: subjectHash,
      subject_anonymised_id: null,
      claim_reference: payload.subject_identification.claim_reference ?? null,
      request_type: payload.request_type,
      request_scope: payload.request_scope,
      specific_class: payload.specific_class,
      verified: false,
      suppression_active: false,
      source_request_metadata: sourceMetadataSafe,
    });

  if (insertErr) {
    const code = (insertErr as { code?: string }).code;
    if (code === '23505') {
      logEvent({
        event_type: 'intake_duplicate' satisfies EventType,
        correlation_id,
        status: 409,
        request_ref: payload.request_ref,
        db_error_code: code,
      });
      return jsonResponse({ error: 'duplicate_request_ref' }, 409, correlation_id);
    }
    logEvent({
      event_type: 'intake_error' satisfies EventType,
      correlation_id,
      status: 500,
      reason: 'persistence_failed',
      request_ref: payload.request_ref,
      db_error_code: code,
      db_error_message: (insertErr as { message?: string }).message,
    });
    return jsonResponse({ error: 'persistence_failed' }, 500, correlation_id);
  }

  const queuedAt = new Date().toISOString();

  logEvent({
    event_type: 'intake_success' satisfies EventType,
    correlation_id,
    status: 202,
    request_ref: payload.request_ref,
    subject_hash: subjectHash,
    submitted_via: payload.submitted_via,
    request_type: payload.request_type,
    request_scope: payload.request_scope,
    queued_at: queuedAt,
    duration_ms: Date.now() - t0,
  });

  return jsonResponse({
    request_ref: payload.request_ref,
    queued_at: queuedAt,
    correlation_id,
  }, 202, correlation_id);
});
