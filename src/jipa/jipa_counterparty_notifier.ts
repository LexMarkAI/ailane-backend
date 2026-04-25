// src/jipa/jipa_counterparty_notifier.ts
// AILANE-CC-BRIEF-DA-04-001 v1.3 §6
// AMD-092 DA-04 · Counterparty Suppression Notifier
//
// Sends a notice to a downstream MCA counterparty when a sustained
// suppression request lands for a data subject whose information was
// previously included in a released JIPA Output. Target latency per
// §1.1 item 5: within 10 business days of Director verification.
//
// Feature-flagged: COUNTERPARTY_NOTIFICATION_ENABLED (default false).
// When false, the function short-circuits and logs the would-be-send
// payload structure WITHOUT invoking Resend. This is the v1.3 expected
// dev/test state because CLM is not yet populated (§6.1).
//
// PII discipline: subject_hash never enters the email body. The body
// identifies scope by CLID and class only. subject_hash is used for
// internal correlation/logging and audit linkage.
//
// Governing: AILANE-SPEC-JIPA-GRD-001 v1.2 §22; AILANE-DPIA-ESTATE-001
//            Addendum v1.3 §5.2.

import type { OutputClass } from './jipa_suppression_filter.ts';

// --- Types --------------------------------------------------------------

// Rich scope bundle. The Director-facing signature per handoff is
// notifyCounterpartyOfSuppression(clid, subjectHash, scope, mcaRef);
// this interface gives `scope` all the context the §6.3 template body
// needs so the signature stays four-positional.
export interface CounterpartyNotificationScope {
  affected_releases: string[]; // release references previously emitted to this counterparty
  effective_from: string;      // ISO-8601 timestamp or YYYY-MM-DD
  counterparty_email: string;  // MCA-established notification address (resolved upstream from CLM)
  suppression_classes?: OutputClass[]; // optional — which classes are affected
}

export interface NotificationResult {
  sent_at: string;
  message_id: string;     // Resend message id on real send; 'stub:<uuid>' when short-circuited
  short_circuited: boolean;
  would_send: EmailEnvelope | null; // populated when short-circuited, null on real send
}

export interface EmailEnvelope {
  from: string;
  to: string;
  subject: string;
  text: string;
}

export interface EmailTransport {
  send(envelope: EmailEnvelope): Promise<{ id: string }>;
}

export interface NotifierDependencies {
  transport?: EmailTransport;
  fromAddress?: string;         // defaults to 'privacy@ailane.ai'
  enabledOverride?: boolean;    // test hook; otherwise read env COUNTERPARTY_NOTIFICATION_ENABLED
  nowIso?: () => string;        // test hook for sent_at
  stubIdGenerator?: () => string; // test hook for stub message_id
}

// --- Env / feature flag -------------------------------------------------

function readEnv(name: string): string | undefined {
  const g = globalThis as unknown as {
    Deno?: { env: { get: (k: string) => string | undefined } };
    process?: { env: Record<string, string | undefined> };
  };
  if (g.Deno?.env?.get) return g.Deno.env.get(name) ?? undefined;
  if (g.process?.env) return g.process.env[name];
  return undefined;
}

function isEnabled(override?: boolean): boolean {
  if (override !== undefined) return override;
  const raw = readEnv('COUNTERPARTY_NOTIFICATION_ENABLED') ?? 'false';
  return raw === 'true' || raw === '1';
}

// --- Template rendering (verbatim §6.3) ---------------------------------

export function renderNotificationEmail(
  clid: string,
  scope: CounterpartyNotificationScope,
): { subject: string; body: string } {
  const subject = `Ailane JIPA Output Suppression Notice — ${clid}`;

  const releasesLine = scope.affected_releases.length > 0
    ? scope.affected_releases.join(', ')
    : '(none on record)';

  // Verbatim §6.3 body. No registered address (per §13).
  // Placeholder substitutions: {CLID} → clid; [list] → releasesLine;
  // [date] → scope.effective_from.
  const body =
`A sustained subject-rights request has been received in respect of data referenced (directly or derivatively) in JIPA Outputs previously released to your organisation under ${clid}.

Per the Master Data Licence Agreement and the Mutual Compliance Attestation executed with AI Lane Limited, please honour this suppression within the 30-day window by removing or restricting the affected data from your ongoing use.

Affected release references: ${releasesLine}
Effective from: ${scope.effective_from}

Reply to this message to acknowledge receipt. Queries to privacy@ailane.ai.

Governing: AILANE-SPEC-JIPA-GRD-001 v1.2 §22; AILANE-DPIA-ESTATE-001 Addendum v1.3 §5.2.

AI Lane Limited · Company No. 17035654 · ICO Reg. 00013389720`;

  return { subject, body };
}

// --- Resend transport factory ------------------------------------------

// Lazy transport factory. Constructed only when actually needed (i.e.
// when the feature flag is enabled AND no transport was injected).
// Imports Resend via npm: URL so the module stays Deno-native and does
// not require a separate package-manifest update.
async function createResendTransport(apiKey: string): Promise<EmailTransport> {
  // deno-lint-ignore no-explicit-any
  const mod: any = await import('npm:resend@4');
  const Resend = mod.Resend;
  const client = new Resend(apiKey);
  return {
    async send(envelope: EmailEnvelope): Promise<{ id: string }> {
      const { data, error } = await client.emails.send({
        from: envelope.from,
        to: envelope.to,
        subject: envelope.subject,
        text: envelope.text,
      });
      if (error) {
        throw new Error(`resend_send_failed: ${error.message ?? 'unknown'}`);
      }
      if (!data?.id) {
        throw new Error('resend_send_failed: no message id returned');
      }
      return { id: data.id };
    },
  };
}

// --- Public API ---------------------------------------------------------

// Director-agreed signature: (clid, subjectHash, scope, mcaRef). A final
// optional `deps` parameter carries DI hooks (transport, env overrides)
// so the function is testable without live Resend / live env.
//
// subject_hash is intentionally NOT embedded in the email body. It is
// emitted only to the structured log line for internal correlation.
export async function notifyCounterpartyOfSuppression(
  clid: string,
  subjectHash: string,
  scope: CounterpartyNotificationScope,
  mcaRef: string,
  deps: NotifierDependencies = {},
): Promise<NotificationResult> {
  const enabled = isEnabled(deps.enabledOverride);
  const fromAddress = deps.fromAddress ?? 'privacy@ailane.ai';
  const nowIso = deps.nowIso ?? (() => new Date().toISOString());
  const stubIdGen = deps.stubIdGenerator ?? (() => {
    // crypto.randomUUID is available in Deno / Node 19+ / modern browsers.
    const rid = (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function')
      ? crypto.randomUUID()
      : `${Date.now().toString(16)}-${Math.random().toString(16).slice(2, 10)}`;
    return `stub:${rid}`;
  });

  const { subject, body } = renderNotificationEmail(clid, scope);
  const envelope: EmailEnvelope = {
    from: fromAddress,
    to: scope.counterparty_email,
    subject,
    text: body,
  };

  // --- SHORT-CIRCUIT PATH (feature flag false) -------------------------
  // Log the would-be-send payload shape and return a stub result. No
  // Resend client is constructed. This is the v1.3 expected path.
  if (!enabled) {
    const sentAt = nowIso();
    const stubId = stubIdGen();
    console.log(JSON.stringify({
      event: 'counterparty_notification_short_circuited',
      reason: 'COUNTERPARTY_NOTIFICATION_ENABLED=false',
      clid,
      subject_hash: subjectHash,
      mca_ref: mcaRef,
      envelope_to: envelope.to,
      envelope_from: envelope.from,
      envelope_subject: envelope.subject,
      envelope_body_length: envelope.text.length,
      affected_releases_count: scope.affected_releases.length,
      effective_from: scope.effective_from,
      suppression_classes: scope.suppression_classes ?? null,
      short_circuited_at: sentAt,
      stub_message_id: stubId,
    }));
    return {
      sent_at: sentAt,
      message_id: stubId,
      short_circuited: true,
      would_send: envelope,
    };
  }

  // --- REAL SEND PATH --------------------------------------------------
  let transport = deps.transport;
  if (!transport) {
    const apiKey = readEnv('RESEND_API_KEY');
    if (!apiKey) {
      throw new Error('RESEND_API_KEY is required when COUNTERPARTY_NOTIFICATION_ENABLED=true');
    }
    transport = await createResendTransport(apiKey);
  }

  const { id } = await transport.send(envelope);
  const sentAt = nowIso();

  console.log(JSON.stringify({
    event: 'counterparty_notification_sent',
    clid,
    subject_hash: subjectHash,
    mca_ref: mcaRef,
    message_id: id,
    envelope_to: envelope.to,
    envelope_from: envelope.from,
    envelope_subject: envelope.subject,
    affected_releases_count: scope.affected_releases.length,
    effective_from: scope.effective_from,
    suppression_classes: scope.suppression_classes ?? null,
    sent_at: sentAt,
  }));

  return {
    sent_at: sentAt,
    message_id: id,
    short_circuited: false,
    would_send: null,
  };
}
