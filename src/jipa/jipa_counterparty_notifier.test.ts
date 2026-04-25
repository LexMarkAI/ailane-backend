// src/jipa/jipa_counterparty_notifier.test.ts
// AILANE-CC-BRIEF-DA-04-001 v1.3 §6
// Verifies the feature-flag short-circuit, template rendering, and the
// PII / banned-phrase / registered-address disciplines. Uses a stub
// EmailTransport; no live Resend call is made.
//
// Run: deno test --no-check src/jipa/jipa_counterparty_notifier.test.ts

import {
  notifyCounterpartyOfSuppression,
  renderNotificationEmail,
  type CounterpartyNotificationScope,
  type EmailEnvelope,
  type EmailTransport,
} from './jipa_counterparty_notifier.ts';

// --- Inline assert (zero network deps) ----------------------------------

function assertEquals(actual: unknown, expected: unknown, msg?: string): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error(
      `assertEquals failed${msg ? ` (${msg})` : ''}\n  expected: ${e}\n  actual:   ${a}`,
    );
  }
}

function assertTrue(cond: boolean, msg: string): void {
  if (!cond) throw new Error(`assertTrue failed: ${msg}`);
}

function assertFalse(cond: boolean, msg: string): void {
  if (cond) throw new Error(`assertFalse failed: ${msg}`);
}

function assertIncludes(haystack: string, needle: string, msg?: string): void {
  if (!haystack.includes(needle)) {
    throw new Error(
      `assertIncludes failed${msg ? ` (${msg})` : ''}\n  needle: ${JSON.stringify(needle)}`,
    );
  }
}

function assertNotIncludes(haystack: string, needle: string, msg?: string): void {
  if (haystack.includes(needle)) {
    throw new Error(
      `assertNotIncludes failed${msg ? ` (${msg})` : ''}\n  unexpected needle: ${JSON.stringify(needle)}`,
    );
  }
}

// --- Fixtures ----------------------------------------------------------

function scopeFixture(): CounterpartyNotificationScope {
  return {
    affected_releases: ['REL-2026-0017', 'REL-2026-0019'],
    effective_from: '2026-04-25',
    counterparty_email: 'compliance@counterparty.example',
    suppression_classes: ['A', 'B'],
  };
}

class RecordingTransport implements EmailTransport {
  public calls: EmailEnvelope[] = [];
  constructor(private readonly messageId: string) {}
  send(envelope: EmailEnvelope): Promise<{ id: string }> {
    this.calls.push(envelope);
    return Promise.resolve({ id: this.messageId });
  }
}

// =====================================================================
// Template-rendering tests
// =====================================================================

Deno.test('renderNotificationEmail: subject contains CLID', () => {
  const { subject } = renderNotificationEmail('CLID-2026-0001', scopeFixture());
  assertEquals(subject, 'Ailane JIPA Output Suppression Notice — CLID-2026-0001');
});

Deno.test('renderNotificationEmail: body contains CLID, release list, effective-from date', () => {
  const { body } = renderNotificationEmail('CLID-2026-0001', scopeFixture());
  assertIncludes(body, 'CLID-2026-0001');
  assertIncludes(body, 'REL-2026-0017, REL-2026-0019');
  assertIncludes(body, 'Effective from: 2026-04-25');
});

Deno.test('renderNotificationEmail: body contains verbatim governing-spec line', () => {
  const { body } = renderNotificationEmail('CLID-X', scopeFixture());
  assertIncludes(body, 'Governing: AILANE-SPEC-JIPA-GRD-001 v1.2 §22; AILANE-DPIA-ESTATE-001 Addendum v1.3 §5.2.');
});

Deno.test('renderNotificationEmail: body contains Company No. and ICO Reg. identifiers', () => {
  const { body } = renderNotificationEmail('CLID-X', scopeFixture());
  assertIncludes(body, 'Company No. 17035654');
  assertIncludes(body, 'ICO Reg. 00013389720');
});

Deno.test('renderNotificationEmail: body contains Resend-reply instruction', () => {
  const { body } = renderNotificationEmail('CLID-X', scopeFixture());
  assertIncludes(body, 'Reply to this message to acknowledge receipt.');
  assertIncludes(body, 'privacy@ailane.ai');
});

Deno.test('renderNotificationEmail: no banned phrases (§13)', () => {
  const { body } = renderNotificationEmail('CLID-X', scopeFixture());
  assertNotIncludes(body.toLowerCase(), 'guaranteed');
  assertNotIncludes(body.toLowerCase(), 'fully compliant');
  assertNotIncludes(body.toLowerCase(), 'eliminates risk');
});

Deno.test('renderNotificationEmail: empty affected_releases renders "(none on record)"', () => {
  const scope = scopeFixture();
  scope.affected_releases = [];
  const { body } = renderNotificationEmail('CLID-X', scope);
  assertIncludes(body, 'Affected release references: (none on record)');
});

// =====================================================================
// Feature-flag short-circuit tests (v1.3 expected path: flag=false)
// =====================================================================

Deno.test('notifyCounterpartyOfSuppression: default flag=false short-circuits (no transport call)', async () => {
  const transport = new RecordingTransport('msg_should_not_be_sent');
  const result = await notifyCounterpartyOfSuppression(
    'CLID-2026-0001',
    'abc123_subject_hash',
    scopeFixture(),
    'MCA-CLID-2026-0001-v1',
    { transport, enabledOverride: false },
  );
  assertTrue(result.short_circuited, 'must short-circuit when flag=false');
  assertTrue(result.message_id.startsWith('stub:'), 'stub message_id prefix');
  assertEquals(transport.calls.length, 0, 'transport must NOT have been invoked');
  assertTrue(result.would_send !== null, 'would_send envelope must be populated on short-circuit');
});

Deno.test('notifyCounterpartyOfSuppression: short-circuit envelope never includes subject_hash', async () => {
  const result = await notifyCounterpartyOfSuppression(
    'CLID-X',
    'sensitive_hash_do_not_leak_ee001122',
    scopeFixture(),
    'MCA-X',
    { enabledOverride: false },
  );
  assertTrue(result.would_send !== null, 'envelope present');
  const env = result.would_send!;
  assertNotIncludes(env.subject, 'sensitive_hash_do_not_leak_ee001122', 'subject must not carry subject_hash');
  assertNotIncludes(env.text, 'sensitive_hash_do_not_leak_ee001122', 'body must not carry subject_hash');
});

Deno.test('notifyCounterpartyOfSuppression: short-circuit result carries stable sent_at via nowIso hook', async () => {
  const result = await notifyCounterpartyOfSuppression(
    'CLID-X',
    'hash_x',
    scopeFixture(),
    'MCA-X',
    {
      enabledOverride: false,
      nowIso: () => '2026-04-25T12:00:00.000Z',
      stubIdGenerator: () => 'stub:deterministic-id',
    },
  );
  assertEquals(result.sent_at, '2026-04-25T12:00:00.000Z');
  assertEquals(result.message_id, 'stub:deterministic-id');
});

// =====================================================================
// Feature-flag enabled path — dependency-injected transport
// =====================================================================

Deno.test('notifyCounterpartyOfSuppression: flag=true invokes the injected transport', async () => {
  const transport = new RecordingTransport('msg_0001_real');
  const result = await notifyCounterpartyOfSuppression(
    'CLID-2026-0002',
    'hash_y',
    scopeFixture(),
    'MCA-CLID-2026-0002-v1',
    { transport, enabledOverride: true },
  );
  assertFalse(result.short_circuited, 'must NOT short-circuit when flag=true');
  assertEquals(result.message_id, 'msg_0001_real');
  assertEquals(result.would_send, null, 'would_send must be null on real send');
  assertEquals(transport.calls.length, 1, 'transport must have been invoked exactly once');

  const envSent = transport.calls[0];
  assertEquals(envSent.to, 'compliance@counterparty.example');
  assertEquals(envSent.from, 'privacy@ailane.ai');
  assertTrue(envSent.subject.startsWith('Ailane JIPA Output Suppression Notice'), 'subject prefix');
});

Deno.test('notifyCounterpartyOfSuppression: fromAddress override honoured', async () => {
  const transport = new RecordingTransport('msg_2');
  await notifyCounterpartyOfSuppression(
    'CLID-X',
    'hash_z',
    scopeFixture(),
    'MCA-X',
    { transport, enabledOverride: true, fromAddress: 'dpo@ailane.ai' },
  );
  assertEquals(transport.calls[0].from, 'dpo@ailane.ai');
});

Deno.test('notifyCounterpartyOfSuppression: envelope body never embeds subject_hash under real-send path either', async () => {
  const transport = new RecordingTransport('msg_3');
  await notifyCounterpartyOfSuppression(
    'CLID-X',
    'dangerous_hash_zzz_ff88',
    scopeFixture(),
    'MCA-X',
    { transport, enabledOverride: true },
  );
  const env = transport.calls[0];
  assertNotIncludes(env.text, 'dangerous_hash_zzz_ff88', 'body must not carry subject_hash');
  assertNotIncludes(env.subject, 'dangerous_hash_zzz_ff88', 'subject must not carry subject_hash');
});
