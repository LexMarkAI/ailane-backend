// src/jipa/jipa_suppression_filter.test.ts
// AILANE-CC-BRIEF-DA-04-001 v1.3 §5.2
// Deno unit tests for the suppression filter. No live database — uses
// a stub SuppressionDataSource via dependency injection.
//
// Run: deno test src/jipa/jipa_suppression_filter.test.ts

import {
  isSuppressed,
  isSuppressedAtTime,
  scopeMatchesClass,
  type AuditRowSnapshot,
  type FeedRowSnapshot,
  type SuppressionDataSource,
} from './jipa_suppression_filter.ts';

// --- Inline assert (zero network deps) ---------------------------------

function assertEquals(actual: unknown, expected: unknown, msg?: string): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error(
      `assertEquals failed${msg ? ` (${msg})` : ''}\n  expected: ${e}\n  actual:   ${a}`,
    );
  }
}

// --- Test stub data source ----------------------------------------------

class StubDataSource implements SuppressionDataSource {
  constructor(
    private readonly feedRows: Map<string, FeedRowSnapshot[]>,
    private readonly auditRows: Map<string, AuditRowSnapshot[]>,
  ) {}

  fetchActiveSuppressionsForSubject(subjectHash: string): Promise<FeedRowSnapshot[]> {
    const all = this.feedRows.get(subjectHash) ?? [];
    return Promise.resolve(all.filter((r) => r.suppression_active));
  }

  fetchLatestAuditRowAtOrBefore(
    subjectHash: string,
    atTime: string,
  ): Promise<AuditRowSnapshot | null> {
    const all = this.auditRows.get(subjectHash) ?? [];
    const cutoff = new Date(atTime).getTime();
    const eligible = all
      .filter((r) => new Date(r.audit_timestamp).getTime() <= cutoff)
      .sort((a, b) =>
        new Date(b.audit_timestamp).getTime() - new Date(a.audit_timestamp).getTime()
      );
    return Promise.resolve(eligible[0] ?? null);
  }
}

// =====================================================================
// isSuppressed — current-state tests (§5.2 group 1)
// =====================================================================

Deno.test('isSuppressed: non-suppressed subject returns suppressed=false', async () => {
  const ds = new StubDataSource(new Map(), new Map());
  const result = await isSuppressed(ds, 'subj_unknown_hash', 'A');
  assertEquals(result, { suppressed: false, scope: null, until: null });
});

Deno.test('isSuppressed: subject with scope covering requested class returns suppressed=true', async () => {
  const feed = new Map<string, FeedRowSnapshot[]>([
    ['subj_X', [{
      request_scope: 'jipa_outputs_only',
      specific_class: null,
      suppression_active: true,
      suppression_scope: { classes: ['A', 'B'] },
      suppression_from: '2026-01-01T00:00:00Z',
      suppression_until: null,
    }]],
  ]);
  const ds = new StubDataSource(feed, new Map());
  const result = await isSuppressed(ds, 'subj_X', 'A');
  assertEquals(result.suppressed, true);
  assertEquals(result.scope, { classes: ['A', 'B'] });
  assertEquals(result.until, null);
});

Deno.test('isSuppressed: scope does NOT cover requested class returns suppressed=false', async () => {
  const feed = new Map<string, FeedRowSnapshot[]>([
    ['subj_X', [{
      request_scope: 'jipa_outputs_only',
      specific_class: null,
      suppression_active: true,
      suppression_scope: { classes: ['A', 'B'] },
      suppression_from: '2026-01-01T00:00:00Z',
      suppression_until: null,
    }]],
  ]);
  const ds = new StubDataSource(feed, new Map());
  const result = await isSuppressed(ds, 'subj_X', 'C');
  assertEquals(result.suppressed, false);
  assertEquals(result.scope, null);
});

Deno.test('isSuppressed: expired suppression_until returns suppressed=false', async () => {
  const feed = new Map<string, FeedRowSnapshot[]>([
    ['subj_E', [{
      request_scope: 'jipa_outputs_only',
      specific_class: null,
      suppression_active: true,
      suppression_scope: { classes: ['A'] },
      suppression_from: '2025-01-01T00:00:00Z',
      suppression_until: '2025-12-31T00:00:00Z', // already past at test time (>= 2026)
    }]],
  ]);
  const ds = new StubDataSource(feed, new Map());
  const result = await isSuppressed(ds, 'subj_E', 'A');
  assertEquals(result.suppressed, false);
});

Deno.test('isSuppressed: future suppression_until returns suppressed=true', async () => {
  const feed = new Map<string, FeedRowSnapshot[]>([
    ['subj_F', [{
      request_scope: 'jipa_outputs_only',
      specific_class: null,
      suppression_active: true,
      suppression_scope: { classes: ['A'] },
      suppression_from: '2026-01-01T00:00:00Z',
      suppression_until: '2099-12-31T00:00:00Z',
    }]],
  ]);
  const ds = new StubDataSource(feed, new Map());
  const result = await isSuppressed(ds, 'subj_F', 'A');
  assertEquals(result.suppressed, true);
});

Deno.test('isSuppressed: suppression_active=false row is ignored even if scope matches', async () => {
  const feed = new Map<string, FeedRowSnapshot[]>([
    ['subj_I', [{
      request_scope: 'jipa_outputs_only',
      specific_class: null,
      suppression_active: false, // unverified intake
      suppression_scope: { classes: ['A'] },
      suppression_from: null,
      suppression_until: null,
    }]],
  ]);
  const ds = new StubDataSource(feed, new Map());
  const result = await isSuppressed(ds, 'subj_I', 'A');
  assertEquals(result.suppressed, false);
});

// =====================================================================
// isSuppressedAtTime — point-in-time tests (§5.2 group 2)
// =====================================================================

Deno.test('isSuppressedAtTime: no audit history returns suppressed=false with audit_id=null', async () => {
  const ds = new StubDataSource(new Map(), new Map());
  const result = await isSuppressedAtTime(ds, 'subj_no_history', 'A', '2026-04-25T00:00:00Z');
  assertEquals(result, {
    suppressed: false,
    scope: null,
    until: null,
    audit_id: null,
    audit_timestamp: null,
  });
});

Deno.test('isSuppressedAtTime: queried for time before activation returns suppressed=false (with INSERT audit_id)', async () => {
  // Subject lifecycle:
  //   2026-03-01 INSERT (verified=false, suppression_active=false)
  //   2026-04-01 UPDATE (verified=true,  suppression_active=true, scope.A)
  // Query at 2026-03-15: between the two — suppression not yet active.
  const audit = new Map<string, AuditRowSnapshot[]>([
    ['subj_T', [
      {
        audit_id: 100,
        audit_timestamp: '2026-03-01T00:00:00Z',
        request_scope: 'jipa_outputs_only',
        specific_class: null,
        suppression_active: false,
        suppression_scope: null,
        suppression_from: null,
        suppression_until: null,
      },
      {
        audit_id: 101,
        audit_timestamp: '2026-04-01T00:00:00Z',
        request_scope: 'jipa_outputs_only',
        specific_class: null,
        suppression_active: true,
        suppression_scope: { classes: ['A'] },
        suppression_from: '2026-04-01T00:00:00Z',
        suppression_until: null,
      },
    ]],
  ]);
  const ds = new StubDataSource(new Map(), audit);
  const result = await isSuppressedAtTime(ds, 'subj_T', 'A', '2026-03-15T00:00:00Z');
  assertEquals(result.suppressed, false);
  assertEquals(result.audit_id, 100);
  assertEquals(result.audit_timestamp, '2026-03-01T00:00:00Z');
});

Deno.test('isSuppressedAtTime: queried for time after activation returns suppressed=true (with UPDATE audit_id)', async () => {
  const audit = new Map<string, AuditRowSnapshot[]>([
    ['subj_T', [
      {
        audit_id: 100,
        audit_timestamp: '2026-03-01T00:00:00Z',
        request_scope: 'jipa_outputs_only',
        specific_class: null,
        suppression_active: false,
        suppression_scope: null,
        suppression_from: null,
        suppression_until: null,
      },
      {
        audit_id: 101,
        audit_timestamp: '2026-04-01T00:00:00Z',
        request_scope: 'jipa_outputs_only',
        specific_class: null,
        suppression_active: true,
        suppression_scope: { classes: ['A'] },
        suppression_from: '2026-04-01T00:00:00Z',
        suppression_until: null,
      },
    ]],
  ]);
  const ds = new StubDataSource(new Map(), audit);
  const result = await isSuppressedAtTime(ds, 'subj_T', 'A', '2026-04-15T00:00:00Z');
  assertEquals(result.suppressed, true);
  assertEquals(result.audit_id, 101);
  assertEquals(result.audit_timestamp, '2026-04-01T00:00:00Z');
  assertEquals(result.scope, { classes: ['A'] });
});

Deno.test('isSuppressedAtTime: returns historical state, not current state (the LAE-001 use case)', async () => {
  // Subject was suppressed for a window then suppression was lifted.
  // Querying within the window must return suppressed=true regardless of
  // the current (post-lift) state. This is the integrity property LAE-001
  // depends on for "what was true at the moment of release_v17?".
  const audit = new Map<string, AuditRowSnapshot[]>([
    ['subj_R', [
      {
        audit_id: 200,
        audit_timestamp: '2026-04-20T00:00:00Z',
        request_scope: 'jipa_outputs_only',
        specific_class: null,
        suppression_active: false,
        suppression_scope: null,
        suppression_from: null,
        suppression_until: null,
      },
      {
        audit_id: 201,
        audit_timestamp: '2026-04-21T00:00:00Z',
        request_scope: 'jipa_outputs_only',
        specific_class: null,
        suppression_active: true,
        suppression_scope: { classes: ['A', 'B'] },
        suppression_from: '2026-04-21T00:00:00Z',
        suppression_until: null,
      },
      {
        audit_id: 202,
        audit_timestamp: '2026-04-25T00:00:00Z',
        request_scope: 'jipa_outputs_only',
        specific_class: null,
        suppression_active: false,
        suppression_scope: { classes: ['A', 'B'] },
        suppression_from: '2026-04-21T00:00:00Z',
        suppression_until: null,
      },
    ]],
  ]);
  const ds = new StubDataSource(new Map(), audit);

  // Mid-window: was active, must return true
  const historical = await isSuppressedAtTime(ds, 'subj_R', 'A', '2026-04-22T00:00:00Z');
  assertEquals(historical.suppressed, true);
  assertEquals(historical.audit_id, 201);

  // Post-lift: now inactive, must return false
  const post = await isSuppressedAtTime(ds, 'subj_R', 'A', '2026-04-26T00:00:00Z');
  assertEquals(post.suppressed, false);
  assertEquals(post.audit_id, 202);
});

Deno.test('isSuppressedAtTime: scope mismatch at queried time returns suppressed=false but cites the audit_id', async () => {
  const audit = new Map<string, AuditRowSnapshot[]>([
    ['subj_S', [{
      audit_id: 300,
      audit_timestamp: '2026-04-01T00:00:00Z',
      request_scope: 'specific_class',
      specific_class: 'A',
      suppression_active: true,
      suppression_scope: { classes: ['A'] },
      suppression_from: '2026-04-01T00:00:00Z',
      suppression_until: null,
    }]],
  ]);
  const ds = new StubDataSource(new Map(), audit);
  const result = await isSuppressedAtTime(ds, 'subj_S', 'C', '2026-04-15T00:00:00Z');
  assertEquals(result.suppressed, false);
  assertEquals(result.audit_id, 300); // audit row was found, just didn't cover class C
  assertEquals(result.scope, null);
});

Deno.test('isSuppressedAtTime: expired suppression_until at queried time returns suppressed=false (cites audit_id)', async () => {
  const audit = new Map<string, AuditRowSnapshot[]>([
    ['subj_X', [{
      audit_id: 400,
      audit_timestamp: '2026-01-01T00:00:00Z',
      request_scope: 'jipa_outputs_only',
      specific_class: null,
      suppression_active: true,
      suppression_scope: { classes: ['A'] },
      suppression_from: '2026-01-01T00:00:00Z',
      suppression_until: '2026-02-01T00:00:00Z',
    }]],
  ]);
  const ds = new StubDataSource(new Map(), audit);
  // Query AFTER suppression_until — even though active=true in the snapshot,
  // the validity window had already closed by atTime.
  const result = await isSuppressedAtTime(ds, 'subj_X', 'A', '2026-03-15T00:00:00Z');
  assertEquals(result.suppressed, false);
  assertEquals(result.audit_id, 400);
});

// =====================================================================
// scopeMatchesClass — pure-helper unit tests
// =====================================================================

Deno.test('scopeMatchesClass: explicit classes array — match', () => {
  assertEquals(scopeMatchesClass({ classes: ['A', 'B'] }, 'jipa_outputs_only', null, 'A'), true);
  assertEquals(scopeMatchesClass({ classes: ['A', 'B'] }, 'jipa_outputs_only', null, 'B'), true);
});

Deno.test('scopeMatchesClass: explicit classes array — no match', () => {
  assertEquals(scopeMatchesClass({ classes: ['A', 'B'] }, 'jipa_outputs_only', null, 'C'), false);
  assertEquals(scopeMatchesClass({ classes: ['A'] }, 'jipa_outputs_only', null, 'family_i'), false);
});

Deno.test('scopeMatchesClass: empty classes array matches nothing', () => {
  assertEquals(scopeMatchesClass({ classes: [] }, 'jipa_outputs_only', null, 'A'), false);
});

Deno.test('scopeMatchesClass: null scope falls back to request_scope=full_estate (matches all)', () => {
  assertEquals(scopeMatchesClass(null, 'full_estate', null, 'A'), true);
  assertEquals(scopeMatchesClass(null, 'full_estate', null, 'family_i'), true);
});

Deno.test('scopeMatchesClass: null scope falls back to request_scope=jipa_outputs_only (matches all)', () => {
  assertEquals(scopeMatchesClass(null, 'jipa_outputs_only', null, 'C'), true);
});

Deno.test('scopeMatchesClass: null scope falls back to specific_class — match', () => {
  assertEquals(scopeMatchesClass(null, 'specific_class', 'A', 'A'), true);
});

Deno.test('scopeMatchesClass: null scope falls back to specific_class — no match', () => {
  assertEquals(scopeMatchesClass(null, 'specific_class', 'A', 'B'), false);
  assertEquals(scopeMatchesClass(null, 'specific_class', null, 'A'), false);
});
