// src/jipa/jipa_suppression_filter.ts
// AILANE-CC-BRIEF-DA-04-001 v1.3 §5
// AMD-092 DA-04 · JIPA Output Suppression Filter (Path 5B — standalone)
// Consumed by the future JIPA output generation layer at output time, and
// by the future LAE-001 release pipeline for point-in-time integrity.
// Governing: AILANE-SPEC-JIPA-GRD-001 v1.2 §22; AILANE-DPIA-ESTATE-001
//            Addendum v1.3 §4.1.

// --- Types --------------------------------------------------------------

export type OutputClass = 'A' | 'B' | 'C' | 'D' | 'E_T1' | 'family_i';

export type RequestScope = 'jipa_outputs_only' | 'full_estate' | 'specific_class';

export interface SuppressionScope {
  classes?: OutputClass[];
  // future-extensible: alins?, cohorts?, jurisdictions?
}

export interface FeedRowSnapshot {
  request_scope: RequestScope;
  specific_class: OutputClass | null;
  suppression_active: boolean;
  suppression_scope: SuppressionScope | null;
  suppression_from: string | null;
  suppression_until: string | null;
}

export interface AuditRowSnapshot extends FeedRowSnapshot {
  audit_id: number;
  audit_timestamp: string;
}

export interface SuppressionDataSource {
  fetchActiveSuppressionsForSubject(subjectHash: string): Promise<FeedRowSnapshot[]>;
  fetchLatestAuditRowAtOrBefore(
    subjectHash: string,
    atTime: string,
  ): Promise<AuditRowSnapshot | null>;
}

export interface SuppressionResult {
  suppressed: boolean;
  scope: SuppressionScope | null;
  until: string | null;
}

export interface PointInTimeSuppressionResult extends SuppressionResult {
  audit_id: number | null;
  audit_timestamp: string | null;
}

// --- Pure helpers (independently testable) ------------------------------

// scope.classes is the source of truth when populated. When null, fall
// back to deriving suppression coverage from request_scope. This handles
// the operational case where Director activates suppression_active=true
// without having authored a structured scope JSON yet.
export function scopeMatchesClass(
  suppressionScope: SuppressionScope | null,
  requestScope: RequestScope,
  specificClass: OutputClass | null,
  outputClass: OutputClass,
): boolean {
  if (suppressionScope && Array.isArray(suppressionScope.classes)) {
    return suppressionScope.classes.includes(outputClass);
  }
  switch (requestScope) {
    case 'full_estate':
    case 'jipa_outputs_only':
      return true;
    case 'specific_class':
      return specificClass === outputClass;
    default:
      return false;
  }
}

function isWithinValidity(suppressionUntil: string | null, atTime: Date): boolean {
  if (suppressionUntil === null) return true;
  return atTime.getTime() <= new Date(suppressionUntil).getTime();
}

// --- Public filter API --------------------------------------------------

// Current-state query — used by the JIPA output generation layer at
// output-emission time. Returns suppressed=true iff any active suppression
// row for the subject covers the requested output class and is within
// validity at the time of the call.
export async function isSuppressed(
  ds: SuppressionDataSource,
  subjectHash: string,
  outputClass: OutputClass,
): Promise<SuppressionResult> {
  const rows = await ds.fetchActiveSuppressionsForSubject(subjectHash);
  const now = new Date();
  for (const row of rows) {
    if (!row.suppression_active) continue;
    if (!isWithinValidity(row.suppression_until, now)) continue;
    if (!scopeMatchesClass(row.suppression_scope, row.request_scope, row.specific_class, outputClass)) {
      continue;
    }
    return {
      suppressed: true,
      scope: row.suppression_scope,
      until: row.suppression_until,
    };
  }
  return { suppressed: false, scope: null, until: null };
}

// Point-in-time query — used by the future LAE-001 release pipeline to
// reconstruct what the suppression state was at the moment a release
// artefact was generated. Reads the latest audit row at or before
// `atTime` for the subject and computes suppression from that snapshot.
//
// Returns audit_id + audit_timestamp identifying the row that gave the
// answer (so callers can cite specific audit evidence). If no audit
// history exists at or before `atTime`, returns suppressed=false with
// both audit fields null.
export async function isSuppressedAtTime(
  ds: SuppressionDataSource,
  subjectHash: string,
  outputClass: OutputClass,
  atTime: string,
): Promise<PointInTimeSuppressionResult> {
  const audit = await ds.fetchLatestAuditRowAtOrBefore(subjectHash, atTime);
  if (!audit) {
    return {
      suppressed: false,
      scope: null,
      until: null,
      audit_id: null,
      audit_timestamp: null,
    };
  }

  const atTimeDate = new Date(atTime);
  const active = audit.suppression_active
    && isWithinValidity(audit.suppression_until, atTimeDate)
    && scopeMatchesClass(
      audit.suppression_scope,
      audit.request_scope,
      audit.specific_class,
      outputClass,
    );

  return {
    suppressed: active,
    scope: active ? audit.suppression_scope : null,
    until: active ? audit.suppression_until : null,
    audit_id: audit.audit_id,
    audit_timestamp: audit.audit_timestamp,
  };
}

// --- Production data source (Supabase-backed) ---------------------------

// Minimal structural type for the Supabase v2 client surface this module
// uses. Avoids a hard import dependency in the test build.
type SupabasePostgrestQuery = {
  select: (cols: string) => SupabasePostgrestQuery;
  eq: (col: string, val: unknown) => SupabasePostgrestQuery;
  lte: (col: string, val: unknown) => SupabasePostgrestQuery;
  order: (col: string, opts: { ascending: boolean }) => SupabasePostgrestQuery;
  limit: (n: number) => SupabasePostgrestQuery;
  maybeSingle: () => Promise<{ data: unknown; error: { message: string } | null }>;
  then: <T>(onfulfilled: (v: { data: unknown; error: { message: string } | null }) => T) => Promise<T>;
};

export interface SupabaseClientLike {
  schema: (s: string) => { from: (t: string) => SupabasePostgrestQuery };
}

export function createSupabaseDataSource(sb: SupabaseClientLike): SuppressionDataSource {
  return {
    async fetchActiveSuppressionsForSubject(subjectHash: string): Promise<FeedRowSnapshot[]> {
      const { data, error } = await sb
        .schema('public')
        .from('jipa_suppression_feed')
        .select(
          'request_scope, specific_class, suppression_active, suppression_scope, suppression_from, suppression_until',
        )
        .eq('subject_hash', subjectHash)
        .eq('suppression_active', true);
      if (error) {
        throw new Error(`fetchActiveSuppressionsForSubject failed: ${error.message}`);
      }
      return (data as FeedRowSnapshot[] | null) ?? [];
    },

    async fetchLatestAuditRowAtOrBefore(
      subjectHash: string,
      atTime: string,
    ): Promise<AuditRowSnapshot | null> {
      const { data, error } = await sb
        .schema('public')
        .from('jipa_suppression_audit_log')
        .select(
          'audit_id, audit_timestamp, request_scope, specific_class, suppression_active, suppression_scope, suppression_from, suppression_until',
        )
        .eq('subject_hash', subjectHash)
        .lte('audit_timestamp', atTime)
        .order('audit_timestamp', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (error) {
        throw new Error(`fetchLatestAuditRowAtOrBefore failed: ${error.message}`);
      }
      return (data as AuditRowSnapshot | null) ?? null;
    },
  };
}
