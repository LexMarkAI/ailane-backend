# DA-04 · JIPA Suppression Workflow · Synthetic End-to-End Runbook

**Brief:** AILANE-CC-BRIEF-DA-04-001 v1.3 §7
**Spec:** AILANE-SPEC-JIPA-GRD-001 v1.2 §22; AILANE-DPIA-ESTATE-001 Addendum v1.3 §4.1
**Operator:** Chairman (Claude.ai Projects) via Supabase MCP
**Pre-conditions:**
- Migration `20260426000001_create_jipa_suppression_feed` applied (§3.1).
- Migration `20260426000002_create_jipa_suppression_audit_log` applied (§3.5).
- Edge function `jipa-suppression-handler` deployed at v2 with the §7 structured-logging refinement.
- Env vars set in Supabase Functions Secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `JIPA_PRIVACY_SHARED_SECRET`.
- `RESEND_API_KEY` already provisioned (per §6 sign-off note); `COUNTERPARTY_NOTIFICATION_ENABLED` left unset (defaults to `false`).

## Synthetic fixture

| Field | Value |
|---|---|
| `request_ref` | `DSR-CC-VERIFY-7-1` |
| `submitted_via` | `api` |
| `submitted_at` | `2026-04-25T03:30:00Z` (Chairman may substitute the actual run timestamp) |
| `normalised_name` | `test, cc verify-7-1` |
| `dob` | `1995-05-05` |
| **expected `subject_hash`** | `f0ff6ababb736259f7ef59289d1030a4223bf0535e33495416d0c6e3ccb43ad1` |
| `claim_reference` | `7777777/2026` |
| `request_type` | `erasure` |
| `request_scope` | `jipa_outputs_only` |
| `specific_class` | `null` |
| `source_metadata` | `{ "purpose": "cc_synthetic_e2e_step_1" }` |

`subject_hash` is `SHA-256(lower("test, cc verify-7-1") + "|" + "1995-05-05")`. Pre-verified locally via `deno eval`; the deployed handler must produce the same value.

---

## Step 1 — POST synthetic intake to the deployed edge function

**Tool:** Supabase MCP `invoke_edge_function` (or equivalent HTTP POST)
**Function:** `jipa-suppression-handler`
**Headers:**
- `Content-Type: application/json`
- `X-Ailane-Privacy-Secret: <JIPA_PRIVACY_SHARED_SECRET>`

**Body:**
```json
{
  "request_ref": "DSR-CC-VERIFY-7-1",
  "submitted_via": "api",
  "submitted_at": "2026-04-25T03:30:00Z",
  "subject_identification": {
    "normalised_name": "test, cc verify-7-1",
    "dob": "1995-05-05",
    "claim_reference": "7777777/2026"
  },
  "request_type": "erasure",
  "request_scope": "jipa_outputs_only",
  "specific_class": null,
  "source_metadata": { "purpose": "cc_synthetic_e2e_step_1" }
}
```

**Expected response:** HTTP 202

```json
{
  "request_ref": "DSR-CC-VERIFY-7-1",
  "queued_at": "<ISO-8601 timestamp>",
  "correlation_id": "<uuid>"
}
```

Response header `X-Correlation-Id: <same uuid>`.

**Capture:** the returned `correlation_id` for cross-referencing in step 1b log spot-check.

**§7 follow-up — log spot-check (1b):** in the function logs, expect two structured JSON lines for this `correlation_id`:
1. `{"event_type":"intake_received","correlation_id":"…","method":"POST",…}`
2. `{"event_type":"intake_success","correlation_id":"…","status":202,"request_ref":"DSR-CC-VERIFY-7-1","subject_hash":"f0ff6ababb…",…}`

PASS if both present and no `auth_failure` / `validation_failure` / `intake_error` / `intake_duplicate` lines for this correlation_id.

---

## Step 2 — Verify feed row landed with `verified=false`

**Tool:** Supabase MCP `execute_sql`

```sql
SELECT id, request_ref, submitted_via, subject_hash, request_type,
       request_scope, specific_class, verified, suppression_active,
       claim_reference, source_request_metadata, created_at
FROM public.jipa_suppression_feed
WHERE request_ref = 'DSR-CC-VERIFY-7-1';
```

**Expected:** exactly 1 row.
- `subject_hash` = `f0ff6ababb736259f7ef59289d1030a4223bf0535e33495416d0c6e3ccb43ad1`
- `verified` = `false`
- `suppression_active` = `false`
- `request_type` = `erasure`
- `request_scope` = `jipa_outputs_only`
- `specific_class` = `null`
- `claim_reference` = `7777777/2026`
- `source_request_metadata` = `{"purpose":"cc_synthetic_e2e_step_1"}` — verify `normalised_name` / `dob` / `subject_identification` keys are absent (PII filter).

**Capture:** the row's `id` (uuid) → reference as `<feed_id>` in subsequent steps. Capture `created_at` → reference as `<t_insert>`.

---

## Step 3 — Verify audit log captured the INSERT

```sql
SELECT audit_id, audit_operation, feed_id, request_ref, subject_hash,
       verified, suppression_active, audit_timestamp, changed_columns
FROM public.jipa_suppression_audit_log
WHERE request_ref = 'DSR-CC-VERIFY-7-1'
ORDER BY audit_timestamp ASC;
```

**Expected:** exactly 1 row.
- `audit_operation` = `INSERT`
- `feed_id` = `<feed_id>`
- `subject_hash` matches step 2
- `verified` = `false`, `suppression_active` = `false`
- `audit_timestamp` matches `<t_insert>` to the microsecond
- `changed_columns` = `null` (only populated on UPDATE)

---

## Step 4 — Director-verification UPDATE (simulate verified flip)

```sql
UPDATE public.jipa_suppression_feed
SET verified = true,
    verified_by = 'cc_synthetic_test',
    verified_at = now(),
    verification_notes = 'DA-04 §7 synthetic E2E step 4',
    suppression_active = true,
    suppression_scope = '{"classes":["A","B"]}'::jsonb,
    suppression_from = now()
WHERE request_ref = 'DSR-CC-VERIFY-7-1'
RETURNING id, verified, suppression_active, suppression_scope, suppression_from, updated_at;
```

**Expected:** 1 row updated.
- `verified` = `true`, `suppression_active` = `true`
- `suppression_scope` = `{"classes":["A","B"]}`
- `suppression_from` ≈ now()

**Capture:** the returned `updated_at` → reference as `<t_activate>`.

---

## Step 5 — Verify audit log captured the UPDATE with `changed_columns`

```sql
SELECT audit_id, audit_operation, audit_timestamp, verified,
       suppression_active, suppression_scope, suppression_from,
       changed_columns
FROM public.jipa_suppression_audit_log
WHERE request_ref = 'DSR-CC-VERIFY-7-1'
ORDER BY audit_timestamp ASC;
```

**Expected:** exactly 2 rows (the INSERT from step 3 + a new UPDATE row).

Row 2:
- `audit_operation` = `UPDATE`
- `audit_timestamp` matches `<t_activate>` to the microsecond
- `verified` = `true`, `suppression_active` = `true`
- `suppression_scope` = `{"classes":["A","B"]}`
- `changed_columns` contains, in any order: `verified`, `suppression_active`, `suppression_scope`, `suppression_from`

**PASS condition:** `changed_columns @> ARRAY['verified','suppression_active','suppression_scope','suppression_from']::text[]`.

---

## Step 6 — Filter check: `isSuppressed(subject_hash, 'A')` → expect `true`

The filter module is consumed in process by future code; for this E2E step Chairman simulates the production query directly via SQL. The query mirrors `createSupabaseDataSource(...).fetchActiveSuppressionsForSubject()` plus the `scopeMatchesClass()` predicate.

```sql
SELECT request_scope, specific_class, suppression_active,
       suppression_scope, suppression_from, suppression_until,
       (suppression_scope -> 'classes') ? 'A' AS class_a_in_scope
FROM public.jipa_suppression_feed
WHERE subject_hash = 'f0ff6ababb736259f7ef59289d1030a4223bf0535e33495416d0c6e3ccb43ad1'
  AND suppression_active = true
  AND (suppression_until IS NULL OR suppression_until > now());
```

**Expected:** 1 row returned with `class_a_in_scope = true`.

→ `isSuppressed(...) = { suppressed: true, scope: {"classes":["A","B"]}, until: null }`

---

## Step 7 — Filter check: `isSuppressed(subject_hash, 'C')` → expect `false`

```sql
SELECT (suppression_scope -> 'classes') ? 'C' AS class_c_in_scope
FROM public.jipa_suppression_feed
WHERE subject_hash = 'f0ff6ababb736259f7ef59289d1030a4223bf0535e33495416d0c6e3ccb43ad1'
  AND suppression_active = true;
```

**Expected:** `class_c_in_scope = false` (scope is `["A","B"]`, does not include `C`).

→ `isSuppressed(...) = { suppressed: false, scope: null, until: null }`

---

## Step 8 — Point-in-time: `isSuppressedAtTime(subject_hash, 'A', <t_insert>)` → expect `false`

Query the audit log as the filter would, asking for the latest row at-or-before `<t_insert>`.

```sql
SELECT audit_id, audit_timestamp, suppression_active, suppression_scope,
       (suppression_scope -> 'classes') ? 'A' AS class_a_in_scope
FROM public.jipa_suppression_audit_log
WHERE subject_hash = 'f0ff6ababb736259f7ef59289d1030a4223bf0535e33495416d0c6e3ccb43ad1'
  AND audit_timestamp <= '<t_insert>'  -- substitute the captured value
ORDER BY audit_timestamp DESC
LIMIT 1;
```

**Expected:** 1 row.
- `audit_id` = the INSERT audit row from step 3
- `suppression_active` = `false`
- `class_a_in_scope` = `false` (scope null at INSERT)

→ `isSuppressedAtTime(...) = { suppressed: false, audit_id: <INSERT audit_id>, audit_timestamp: <t_insert>, ... }`

This is the LAE-001 integrity property: **historical state, not current state**. At `<t_insert>` the suppression had not yet been activated.

---

## Step 9 — Point-in-time: `isSuppressedAtTime(subject_hash, 'A', <t_activate> + 1s)` → expect `true`

```sql
SELECT audit_id, audit_timestamp, suppression_active, suppression_scope,
       (suppression_scope -> 'classes') ? 'A' AS class_a_in_scope
FROM public.jipa_suppression_audit_log
WHERE subject_hash = 'f0ff6ababb736259f7ef59289d1030a4223bf0535e33495416d0c6e3ccb43ad1'
  AND audit_timestamp <= '<t_activate_plus_1s>'  -- substitute
ORDER BY audit_timestamp DESC
LIMIT 1;
```

**Expected:** 1 row.
- `audit_id` = the UPDATE audit row from step 5
- `suppression_active` = `true`
- `class_a_in_scope` = `true`

→ `isSuppressedAtTime(...) = { suppressed: true, audit_id: <UPDATE audit_id>, audit_timestamp: <t_activate>, scope: {"classes":["A","B"]}, until: null }`

---

## Step 10 — Counterparty notifier: feature-flag-on path with stub transport

This step is executed locally via Deno (not against the live deployment) because the notifier is an in-process module, not an Edge Function. Run from the repo root:

```bash
deno test --no-check src/jipa/jipa_counterparty_notifier.test.ts
```

**Expected:** `13 passed | 0 failed`. The four short-circuit tests + three real-send tests collectively cover §7.10.

For an additional fixture-driven smoke (optional), Chairman may eval inline:

```bash
deno eval '
import { notifyCounterpartyOfSuppression } from "./src/jipa/jipa_counterparty_notifier.ts";
const recorded = [];
const transport = { send: (env) => { recorded.push(env); return Promise.resolve({id:"resend_synthetic_msg_001"}); } };
const r = await notifyCounterpartyOfSuppression(
  "CLID-2026-9999",
  "f0ff6ababb736259f7ef59289d1030a4223bf0535e33495416d0c6e3ccb43ad1",
  { affected_releases:["REL-2026-0001"], effective_from:"2026-04-25",
    counterparty_email:"compliance@cc.test", suppression_classes:["A","B"] },
  "MCA-CLID-2026-9999-v1",
  { transport, enabledOverride: true },
);
console.log(JSON.stringify({ result: r, envelope_to: recorded[0].to, body_excludes_subject_hash: !recorded[0].text.includes("f0ff6ababb") }, null, 2));
'
```

**Expected:** `result.message_id === "resend_synthetic_msg_001"`, `result.short_circuited === false`, `body_excludes_subject_hash === true`.

---

## Step 11 — Clean up synthetic feed row (audit log retained)

```sql
DELETE FROM public.jipa_suppression_feed
WHERE request_ref = 'DSR-CC-VERIFY-7-1'
RETURNING id, request_ref;
```

**Expected:** 1 row deleted.

The trigger fires AFTER DELETE, so a third audit row is appended capturing `audit_operation = 'DELETE'`. This is by design — the audit log is append-only.

---

## Step 12 — Verify audit log retains the full history of the synthetic run

```sql
SELECT audit_id, audit_operation, audit_timestamp, verified,
       suppression_active, changed_columns
FROM public.jipa_suppression_audit_log
WHERE request_ref = 'DSR-CC-VERIFY-7-1'
ORDER BY audit_timestamp ASC;
```

**Expected:** exactly 3 rows in chronological order:

| Row | audit_operation | verified | suppression_active | notes |
|---|---|---|---|---|
| 1 | INSERT | false | false | step 1 intake |
| 2 | UPDATE | true  | true  | step 4 Director verify; `changed_columns` ⊇ {verified, suppression_active, suppression_scope, suppression_from} |
| 3 | DELETE | true  | true  | step 11 cleanup; `changed_columns` = null |

PASS condition for §7.12: all 3 rows present, append-only behaviour confirmed.

Also verify the feed row is gone:

```sql
SELECT count(*) FROM public.jipa_suppression_feed WHERE request_ref = 'DSR-CC-VERIFY-7-1';
-- Expected: 0
```

---

## Reporting template (Chairman → Director after run)

```
DA-04 §7 SYNTHETIC E2E REPORT

Step 1  POST → 202                              [PASS/FAIL]
Step 1b Log spot-check (intake_received +
        intake_success for correlation_id)      [PASS/FAIL]
Step 2  Feed row landed; PII filter             [PASS/FAIL]
Step 3  Audit log INSERT row                    [PASS/FAIL]
Step 4  Director-verify UPDATE                  [PASS/FAIL]
Step 5  Audit log UPDATE row + changed_columns  [PASS/FAIL]
Step 6  isSuppressed('A') = true                [PASS/FAIL]
Step 7  isSuppressed('C') = false               [PASS/FAIL]
Step 8  isSuppressedAtTime(t_insert) = false    [PASS/FAIL]
Step 9  isSuppressedAtTime(t_activate+1s)= true [PASS/FAIL]
Step 10 Notifier flag-on stub-transport         [PASS/FAIL]
Step 11 Feed-row cleanup                        [PASS/FAIL]
Step 12 Audit log retains 3-row history         [PASS/FAIL]
```
