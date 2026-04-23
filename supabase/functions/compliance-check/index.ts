// compliance-check v42 — engine v26
//
// Phase 2 of CCA-002 per AMD-076 (ratified 22 April 2026).
// DPIA addendum AMD-078 v1.3 ratified 22 April 2026.
//
// ZDR POSTURE (interim, per AILANE-LC-OP-CCA-002-001 Director's Review Note 21 April 2026):
//   Anthropic Zero Data Retention (ZDR) is deferred on funding grounds. This Edge Function operates
//   under Anthropic's standard data retention terms. Re-triggers for ZDR activation: first paying
//   Governance/Institutional client / Phase 1 go-live / GBP 100k cumulative revenue / ICO inquiry.
//   See DPIA §5.2 G6 and AILANE-LC-OP-CCA-002-001 for full interim-risk acceptance.
//
// BINDING DESIGN BOUNDARY (DPIA §4.2):
//   This Edge Function MUST NOT invoke voyage-law-2 at runtime. Runtime retrieval uses pre-computed
//   embeddings stored in regulatory_requirements.embedding + pgvector cosine similarity only.
//   Voyage invocation is confined to the backfill script (ailane-backend/scripts/phase2/).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_API_KEY = (Deno.env.get("ANTHROPIC_API_KEY") || "").trim();

const ENGINE_VERSION = "v26";

const DOC_TYPE_MAP: Record<string, string> = {
  employment_contract: "contract",
  employment_contract_employer: "contract",
  employment_contract_worker: "contract",
  contract: "contract",
  staff_handbook: "handbook",
  handbook: "handbook",
  workplace_policy: "handbook",
};

const SPARSE_THRESHOLD = 0.50;

const TIER_CHAR_LIMITS: Record<string, number> = {
  one_time_scan: 37_500,
  operational: 75_000,
  governance: 150_000,
  institutional: Number.MAX_SAFE_INTEGER,
};
const DEFAULT_CHAR_LIMIT = 37_500;

// Full model chain for pre-screening and lightweight calls
const MODEL_CHAIN = [
  "claude-sonnet-4-6",
  "claude-sonnet-4-5",
  "claude-3-5-sonnet-20241022",
  "claude-haiku-4-5-20251001",
];

// v26: 3-model fallback chain per CCA-002 §4.5.5 and DPIA §5.2 G5
// Per-model timeouts: 45s / 35s / 25s = 105s worst case per batch
// Parallel batches (A, B, F) run concurrently; total wall clock <= 120s (< 150s cap)
const BATCH_MODELS = [
  "claude-sonnet-4-6",
  "claude-sonnet-4-5",
  "claude-haiku-4-5-20251001",
];
const BATCH_TIMEOUTS_MS = [45_000, 35_000, 25_000];

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function triggerEmail(upload_id: string) {
  fetch(`${SUPABASE_URL}/functions/v1/send-report-email`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
    body: JSON.stringify({ upload_id }),
  })
    .then((r) => r.json())
    .then((d) => console.log(`[${ENGINE_VERSION}] Email: sent=${d.sent} to=${d.to}`))
    .catch((e) => console.error(`[${ENGINE_VERSION}] Email failed: ${e.message}`));
}

async function callClaude(
  system: string,
  user: string,
  maxTokens = 6000,
  abortMs = 55_000,
  models?: string[],
  timeoutsMs?: number[],
): Promise<{ text: string; model: string; ms: number; inputTokens: number; outputTokens: number }> {
  if (!ANTHROPIC_API_KEY) throw new Error("ANTHROPIC_API_KEY not configured");
  const t0 = Date.now();
  const errors: string[] = [];
  const modelList = models || MODEL_CHAIN;
  for (let i = 0; i < modelList.length; i++) {
    const model = modelList[i];
    const timeout = timeoutsMs?.[i] ?? abortMs;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeout);
    try {
      console.log(`[${ENGINE_VERSION}] Trying ${model} (timeout=${timeout}ms)...`);
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({ model, max_tokens: maxTokens, system, messages: [{ role: "user", content: user }] }),
        signal: controller.signal,
      });
      clearTimeout(timer);
      if (r.status === 401) { const b = await r.text(); throw new Error(`API key rejected (401): ${b.slice(0, 200)}`); }
      if (r.status === 404 || r.status === 529) { errors.push(`${model}: ${r.status}`); await r.text(); continue; }
      if (!r.ok) { const b = await r.text(); errors.push(`${model}: ${r.status} ${b.slice(0, 150)}`); continue; }
      const d = await r.json();
      const text = d.content?.find((b: any) => b.type === "text")?.text;
      if (!text) throw new Error(`Empty response from ${model}`);
      const inputTokens = d.usage?.input_tokens ?? 0;
      const outputTokens = d.usage?.output_tokens ?? 0;
      console.log(`[${ENGINE_VERSION}] ✓ ${model} in ${Date.now() - t0}ms (in=${inputTokens} out=${outputTokens})`);
      return { text, model, ms: Date.now() - t0, inputTokens, outputTokens };
    } catch (e) {
      clearTimeout(timer);
      if ((e as Error).message?.includes("401")) throw e;
      if ((e as Error).name === "AbortError") { errors.push(`${model}: aborted after ${timeout}ms`); continue; }
      errors.push(`${model}: ${(e as Error).message}`);
      continue;
    }
  }
  throw new Error(`All models failed: ${errors.join(" | ")}`);
}

interface GroundingRef {
  source: "provision" | "case";
  id: string;
  citation: string;
  snippet: string;
  distance: number;
}

async function retrieveGrounding(
  supabase: any,
  requirementId: string,
  topKProvisions = 3,
  topKCases = 2,
): Promise<GroundingRef[]> {
  // Uses ONLY pre-computed embeddings + pgvector cosine similarity.
  // NO Voyage API invocation at runtime (§4.2 DPIA boundary).

  const { data: reqRow, error: reqErr } = await supabase
    .from("regulatory_requirements")
    .select("id, embedding")
    .eq("id", requirementId)
    .single();

  if (reqErr || !reqRow?.embedding) {
    console.warn(`[${ENGINE_VERSION}] No embedding for requirement ${requirementId}`);
    return [];
  }

  const { data: provisions, error: provErr } = await supabase.rpc("kl_grounding_search_provisions", {
    query_embedding: reqRow.embedding,
    match_count: topKProvisions,
  });

  const { data: cases, error: casesErr } = await supabase.rpc("kl_grounding_search_cases", {
    query_embedding: reqRow.embedding,
    match_count: topKCases,
  });

  const refs: GroundingRef[] = [];

  if (!provErr && Array.isArray(provisions)) {
    for (const p of provisions) {
      refs.push({
        source: "provision",
        id: p.provision_id,
        citation: `${p.instrument_id || ""} ${p.section_num || ""}`.trim(),
        snippet: (p.summary || p.current_text || "").slice(0, 300),
        distance: Number(p.distance) || 0,
      });
    }
  }

  if (!casesErr && Array.isArray(cases)) {
    for (const c of cases) {
      refs.push({
        source: "case",
        id: c.case_id,
        citation: c.citation || "",
        snippet: (c.facts || "").slice(0, 300),
        distance: Number(c.distance) || 0,
      });
    }
  }

  return refs;
}

interface ModelPricing { input_usd_per_mtok: number; output_usd_per_mtok: number; }

async function fetchModelPricing(supabase: any): Promise<Map<string, ModelPricing>> {
  const { data, error } = await supabase
    .from("eileen_model_pricing")
    .select("model_name, input_usd_per_mtok, output_usd_per_mtok")
    .is("effective_to", null);

  const map = new Map<string, ModelPricing>();
  if (!error && Array.isArray(data)) {
    for (const row of data) {
      map.set(row.model_name, {
        input_usd_per_mtok: Number(row.input_usd_per_mtok),
        output_usd_per_mtok: Number(row.output_usd_per_mtok),
      });
    }
  }
  return map;
}

function computeCallCostUsd(
  model: string,
  inputTokens: number,
  outputTokens: number,
  pricing: Map<string, ModelPricing>,
): number {
  const p = pricing.get(model);
  if (!p) return 0;
  const inCost = (inputTokens / 1_000_000) * p.input_usd_per_mtok;
  const outCost = (outputTokens / 1_000_000) * p.output_usd_per_mtok;
  return Math.round((inCost + outCost) * 1_000_000) / 1_000_000; // 6dp
}

async function preScreenDocument(docText: string, declaredType: string): Promise<{ inScope: boolean; detectedType: string; reason: string }> {
  const system = `You are a document classification assistant for Ailane, a UK employment law compliance platform.
Determine whether the submitted document is within scope for UK employment law compliance analysis, and critically, identify the CORRECT document type.

IN SCOPE: Employment contracts, staff handbooks, workplace policies, offer letters, apprenticeship agreements.
OUT OF SCOPE: B2B commercial contracts, tenancy/property agreements, financial/loan documents, legal correspondence, corporate articles, invoices, internal technical documents, gibberish/test files.

DOCUMENT TYPE CLASSIFICATION — this determines which requirement library is applied:

STAFF HANDBOOK (detected_type = "staff_handbook"):
- Multiple distinct policy sections with separate headings (Disciplinary, Grievance, Leave, H&S, etc.)
- ACAS Code of Practice language or references
- Organisational scope language ("all employees", "this handbook applies to", "company policy")
- Table of contents covering multiple employment policy domains
- References to multiple statutory instruments across different areas
- Section numbering suggesting a multi-chapter document
- ABSENCE of individual employee name, specific salary, or specific start date
- Terms like "handbook", "employee guide", "company policies", "staff handbook"

EMPLOYMENT CONTRACT (detected_type = "employment_contract"):
- Named employer AND named employee/worker (two specific parties)
- Specific start date, job title, and remuneration for an individual
- Written statement of particulars structure (ERA 1996 s.1 pattern)
- Individual terms and conditions focus
- Notice period specific to this individual
- Signatures or signature blocks for both parties

WORKPLACE POLICY (detected_type = "workplace_policy"):
- Single-topic focus (e.g. only data protection, only flexible working)
- Named policy owner or approver
- Review date and version reference
- Not a multi-domain handbook — focused on one policy area

TIE-BREAKER: If the document is ambiguous between a contract and a handbook, classify as "staff_handbook" — the handbook assessment is more comprehensive and will catch contract-relevant findings.

Respond ONLY with valid JSON, no markdown:
{"in_scope":true,"detected_type":"employment_contract","confidence":"high","reason":"One sentence."}`;
  const sample = docText.length > 3000 ? docText.substring(0, 3000) : docText;
  try {
    const result = await callClaude(system, `Type: "${declaredType}"\n\n${sample}`, 300, 15_000);
    let cleaned = result.text.trim().replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/, "").trim();
    const parsed = JSON.parse(cleaned);
    console.log(`[${ENGINE_VERSION}] Pre-screen: in_scope=${parsed.in_scope} type=${parsed.detected_type}`);
    return { inScope: parsed.in_scope === true, detectedType: parsed.detected_type || "unknown", reason: parsed.reason || "" };
  } catch (e) {
    console.warn(`[${ENGINE_VERSION}] Pre-screen failed, defaulting to in-scope: ${(e as Error).message}`);
    return { inScope: true, detectedType: "unknown", reason: "Pre-screen unavailable." };
  }
}

interface DocSection { heading: string; level: number; content: string; }

async function parseDocx(buf: ArrayBuffer): Promise<{ sections: DocSection[]; fullText: string }> {
  const JSZip = (await import("https://esm.sh/jszip@3.10.1")).default;
  const zip = await JSZip.loadAsync(buf);
  const xml = await zip.file("word/document.xml")?.async("string");
  if (!xml) throw new Error("Invalid DOCX: no word/document.xml");
  const paragraphs: { text: string; style: string; isHeading: boolean; level: number }[] = [];
  const pRegex = /<w:p[\s>][\s\S]*?<\/w:p>/g;
  let m;
  while ((m = pRegex.exec(xml)) !== null) {
    const pXml = m[0];
    const styleMatch = pXml.match(/<w:pStyle\s+w:val="([^"]+)"/);
    const style = styleMatch ? styleMatch[1] : "Normal";
    const textParts: string[] = [];
    const tRegex = /<w:t(?:\s[^>]*)?>([^<]*)<\/w:t>/g;
    let t;
    while ((t = tRegex.exec(pXml)) !== null) textParts.push(t[1]);
    const text = textParts.join("").trim();
    if (!text) continue;
    const decoded = text.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&#x([0-9A-Fa-f]+);/g, (_, h) => String.fromCharCode(parseInt(h, 16))).replace(/&#(\d+);/g, (_, d) => String.fromCharCode(parseInt(d)));
    const isHeading = /^Heading\d/.test(style) || /^Title/.test(style);
    const levelMatch = style.match(/Heading(\d)/);
    paragraphs.push({ text: decoded, style, isHeading, level: isHeading ? (levelMatch ? parseInt(levelMatch[1]) : 0) : 0 });
  }
  const sections: DocSection[] = [];
  let cur: DocSection | null = null;
  for (const p of paragraphs) {
    if (p.isHeading) { if (cur) sections.push(cur); cur = { heading: p.text, level: p.level, content: "" }; } else { if (!cur) cur = { heading: "[Document Start]", level: 0, content: "" }; cur.content += (cur.content ? "\n" : "") + p.text; }
  }
  if (cur) sections.push(cur);
  return { sections, fullText: paragraphs.map((p) => p.text).join("\n") };
}

function extractPdfText(buf: ArrayBuffer): string {
  const raw = new TextDecoder("latin1").decode(new Uint8Array(buf));
  const parts: string[] = [];
  const btEt = /BT[\s\S]*?ET/g;
  let m;
  while ((m = btEt.exec(raw)) !== null) {
    const tjs = m[0].match(/\(([^)]*?)\)\s*Tj/g);
    if (tjs) for (const tj of tjs) { const i = tj.match(/\(([^)]*?)\)/); if (i) parts.push(i[1]); }
    const tjas = m[0].match(/\[([^\]]*)\]\s*TJ/g);
    if (tjas) for (const tja of tjas) { const ss = tja.match(/\(([^)]*?)\)/g); if (ss) for (const s of ss) { const i = s.match(/\(([^)]*?)\)/); if (i) parts.push(i[1]); } }
  }
  let text = parts.join(" ").trim();
  if (text.length < 100) text = raw.replace(/[^\x20-\x7E\n\r]/g, " ").replace(/\s{3,}/g, " ").trim();
  return text;
}

interface Finding {
  upload_id: string;
  clause_text: string;
  clause_category: string;
  statutory_ref: string;
  requirement_id: string;
  severity: string;
  finding_detail: string;
  remediation: string | null;
  pillar_mapping: string;
  pillar_mapping_type: string;
  engine_version: string;
  is_forward_looking: boolean;
  forward_effective_date: string | null;
  forward_source_act: string | null;
  grounding_refs: GroundingRef[] | null;
  model_cost_usd: number | null;
}

function computeScore(findings: Finding[]): { overallScore: number; translatedPillarScore: number } {
  const currentFindings = findings.filter((f) => !f.is_forward_looking);
  if (currentFindings.length === 0) return { overallScore: 0, translatedPillarScore: 0 };
  const weights: Record<string, number> = { compliant: 1.0, minor: 0.7, major: 0.3, critical: 0.0 };
  let wSum = 0, wTotal = 0;
  for (const f of currentFindings) {
    const w = weights[f.severity] ?? 0;
    const mult = f.severity === "critical" ? 2.0 : 1.0;
    wSum += w * mult;
    wTotal += mult;
  }
  const overallScore = wTotal > 0 ? Math.round((wSum / wTotal) * 100 * 100) / 100 : 0;
  let ts = overallScore >= 65 ? 3 : overallScore >= 30 ? 2 : overallScore >= 1 ? 1 : 0;
  if (currentFindings.some((f) => f.severity === "critical") && ts > 2) ts = 2;
  return { overallScore, translatedPillarScore: ts };
}

function parseAnalysisResult(raw: string, label: string): any[] {
  let cleaned = raw.trim();
  if (cleaned.startsWith("```")) cleaned = cleaned.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/, "").trim();
  const arrayStart = cleaned.indexOf("[");
  const arrayEnd = cleaned.lastIndexOf("]");
  if (arrayStart !== -1 && arrayEnd > arrayStart) cleaned = cleaned.slice(arrayStart, arrayEnd + 1);
  const parsed = JSON.parse(cleaned);
  if (!Array.isArray(parsed)) throw new Error("Not an array");
  console.log(`[${ENGINE_VERSION}] Parsed ${label}: ${parsed.length} items`);
  return parsed;
}

function matchRequirements(analysisItems: any[], batchReqs: any[], reqMap: Map<string, any>, reqNameMap: Map<string, any>, label: string): Array<{ ar: any; req: any }> {
  const matched: Array<{ ar: any; req: any }> = [];
  const usedReqIds = new Set<string>();
  for (let i = 0; i < analysisItems.length; i++) {
    const ar = analysisItems[i];
    let req = ar.requirement_id ? reqMap.get(ar.requirement_id) : undefined;
    if (!req && ar.requirement_name) {
      const normalised = ar.requirement_name.toLowerCase().replace(/[^a-z0-9 ]/g, "").trim();
      req = reqNameMap.get(normalised);
      if (!req) { const partial = normalised.substring(0, 30); for (const [k, v] of reqNameMap.entries()) { if (k.startsWith(partial) || partial.startsWith(k.substring(0, 30))) { req = v; break; } } }
    }
    if (!req && i < batchReqs.length) { req = batchReqs[i]; console.log(`[${ENGINE_VERSION}] Batch ${label}[${i}]: positional match → ${req.requirement_name}`); }
    if (!req) { console.warn(`[${ENGINE_VERSION}] Batch ${label}[${i}]: no match`); continue; }
    if (usedReqIds.has(req.id)) { console.warn(`[${ENGINE_VERSION}] Batch ${label}[${i}]: duplicate, skipping`); continue; }
    usedReqIds.add(req.id);
    matched.push({ ar, req });
  }
  return matched;
}

const ANALYSIS_SYSTEM_PROMPT = `You are a senior UK employment law compliance analyst working for Ailane, an institutional-grade regulatory intelligence platform. Your analysis will be delivered directly to HR directors and business owners who are paying for expert-level findings. The quality standard is that of a specialist employment law barrister reviewing a contract.

For EACH requirement provided, you must:

1. READ the full document carefully and locate the relevant clause or section
2. Extract the EXACT clause text (verbatim quote with clause number, e.g. "Clause 9.4: ...") or "[Not found in document]" if absent
3. Assign severity using this strict guide:
   - compliant: clause meets the statutory standard fully and unambiguously
   - minor: clause addresses the requirement but is vague, incomplete, or could be clearer — not unlawful but suboptimal
   - major: clause is substantively inadequate, creates significant legal risk, or fails to meet the statutory standard without being outright void
   - critical: clause is UNLAWFUL, VOID, or UNENFORCEABLE under UK law OR a mandatory statutory requirement is entirely absent
4. Write a precise finding (2-4 sentences) that:
   - Cites the specific clause number(s) by reference
   - Names the exact statutory provision (e.g. ERA 1996 s.13, WTR 1998 Reg.16)
   - Identifies the specific legal deficiency
   - References relevant case law where it materially affects the position (e.g. Brazel v Harpur Trust [2022] UKSC 27)
5. Provide a specific, actionable remediation — what exactly must be changed, added, or removed, and what it should say instead

Additional requirements:
- Flag any terms that are UNLAWFUL or VOID not covered by the listed requirements — add these as additional findings
- EMPLOYMENT RIGHTS ACT 2025 AWARENESS (as of March 2026):
  The Employment Rights Act 2025 (c. 36) received Royal Assent on 18 December 2025.
  Implementation is PHASED. You must distinguish between current law and pending provisions:
  ALREADY IN FORCE:
    - Repeal of Strikes (Minimum Service Levels) Act 2023 (18 December 2025)
    - ACAS Early Conciliation period extended from 6 to 12 weeks (1 December 2025)
    - Dismissal during industrial action automatically unfair — 12-week limit removed (18 February 2026)
    - Trade union ballot support threshold (40% in key services) removed (18 February 2026)
    - Day-one paternity leave and ordinary parental leave (6 April 2026)
  NOT YET IN FORCE (do NOT treat these as current law when assessing compliance):
    - Unfair dismissal qualifying period reduces from 2 years to 6 months (expected 1 January 2027)
    - Unfair dismissal compensation cap removed (expected alongside qualifying period change)
    - Fire-and-rehire becomes automatically unfair for restricted variations (expected 1 January 2027)
    - SSP waiting days abolished and lower earnings limit removed (expected 2026, commencement pending)
    - Zero-hours contracts guaranteed hours obligations (expected 2027)
    - Reasonable notice of shifts and cancelled shift compensation (expected 2027)
    - Sexual harassment reasonable steps specification (expected October 2026)
    - Employment tribunal time limits extended from 3 to 6 months (expected 2026-2027)
  When a document's clauses relate to provisions not yet in force, note the pending change as a
  FORWARD-LOOKING observation but do NOT mark the clause as non-compliant solely because it does
  not yet reflect law that has not commenced.
- For permanent contracts: "Expected duration" is compliant by nature
- Never produce vague findings — every finding must be specific to the clause and statute
- Remediation must be specific enough that a solicitor could draft the corrected clause from it

CRITICAL INSTRUCTION: You must return EXACTLY one JSON object per requirement listed, in the SAME ORDER as the requirements appear in the list. Use the exact requirement_id value provided — do not reformat, abbreviate, or change it. Do not skip any requirement.

Respond ONLY with a valid JSON array — no preamble, no markdown, no commentary:
[{
  "requirement_name": "exact name from the requirement list",
  "requirement_id": "exact ID from the requirement list",
  "severity": "compliant|minor|major|critical",
  "clause_text": "Clause X.X: verbatim text, or [Not found in document]",
  "finding_detail": "Specific finding citing clause number and statutory provision",
  "remediation": "Specific actionable remediation, or null if compliant"
}]`;

const FORWARD_SYSTEM_PROMPT = `You are a senior UK employment law forward-exposure analyst working for Ailane, an institutional-grade regulatory intelligence platform. You are performing a FORWARD-LOOKING LEGISLATIVE HORIZON analysis — NOT a current compliance assessment.

Your task: assess whether the document's existing clauses will REMAIN compliant once specific forthcoming provisions of the Employment Rights Act 2025 come into force. These provisions have received Royal Assent but have NOT YET COMMENCED.

This is predictive intelligence. The client will see these findings clearly labelled as "Legislative Horizon — Forward Exposure" findings, separate from their current compliance score. Forward findings do NOT affect their current compliance score.

For EACH future requirement provided, you must:

1. READ the full document carefully for any clause relevant to the forthcoming provision
2. Extract the EXACT clause text if one exists, or state "[No existing clause addresses this provision]" if the document is silent
3. Assess the FUTURE IMPACT using this severity guide:
   - compliant: the existing clause already anticipates the forthcoming change and will remain compliant when the provision commences — no action needed
   - minor: the clause is acceptable but uses language or references that will become outdated or incomplete — update recommended but no legal liability
   - major: the clause will become substantively non-compliant or create significant legal exposure once the provision commences — action required before commencement date
   - critical: the clause contains terms that will become UNLAWFUL or VOID once the provision commences, OR the absence of any clause addressing a mandatory forthcoming requirement will create immediate non-compliance on commencement
4. Write a precise finding (2-4 sentences) that:
   - States what the document currently says (or doesn't say)
   - Identifies the specific ERA 2025 provision that will affect it
   - States the expected commencement date
   - Explains the specific exposure that will arise if the clause is not updated
5. Provide a specific, actionable remediation that tells the employer EXACTLY what to change and by when

TONE AND FRAMING:
- This is intelligence, not a compliance failure notice. Frame findings as "upcoming exposure" not "current violations"
- Use language like: "When [provision] commences on [date], this clause will...", "Ahead of [date], consider updating...", "This clause does not yet reflect [forthcoming change]"
- Every finding must reference the specific commencement date from the requirement
- Make it clear this is forward planning, not a current legal deficiency

CRITICAL INSTRUCTION: Return EXACTLY one JSON object per requirement, in the SAME ORDER. Use the exact requirement_id provided.

Respond ONLY with a valid JSON array:
[{
  "requirement_name": "exact name from the requirement list",
  "requirement_id": "exact ID from the requirement list",
  "severity": "compliant|minor|major|critical",
  "clause_text": "Clause X.X: verbatim text, or [No existing clause addresses this provision]",
  "finding_detail": "Forward-looking finding with commencement date and specific exposure",
  "remediation": "Specific action with deadline, or null if compliant"
}]`;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  let upload_id = "";

  try {
    const body = await req.json();
    upload_id = body.upload_id || "";
    if (!upload_id) return jsonResponse({ error: "upload_id required" }, 400);
    console.log(`[${ENGINE_VERSION}] ── START ${upload_id} ──`);

    const { data: upload, error: fetchErr } = await supabase.from("compliance_uploads").select("*").eq("id", upload_id).single();
    if (fetchErr || !upload) return jsonResponse({ error: "Upload not found" }, 404);
    if (upload.evidence_track !== "documentary") return jsonResponse({ error: "Only Track B" }, 400);

    await supabase.from("compliance_uploads").update({ status: "processing" }).eq("id", upload_id);

    const { data: fileData, error: dlErr } = await supabase.storage.from("compliance-documents").download(upload.file_path);
    if (dlErr || !fileData) throw new Error(`Download failed: ${dlErr?.message}`);

    const fileBuffer = await fileData.arrayBuffer();
    const fname = (upload.file_name || "").toLowerCase();
    let fullText: string;
    let sections: DocSection[];

    if (fname.endsWith(".docx")) {
      const parsed = await parseDocx(fileBuffer); fullText = parsed.fullText; sections = parsed.sections;
    } else if (fname.endsWith(".pdf")) {
      fullText = extractPdfText(fileBuffer); sections = [{ heading: "[PDF]", level: 0, content: fullText }];
    } else {
      throw new Error(`Unsupported file type: ${fname}`);
    }

    console.log(`[${ENGINE_VERSION}] Parsed: ${fullText.length} chars, ${sections.length} sections`);

    if (!fullText || fullText.length < 30) {
      await supabase.from("compliance_uploads").update({ status: "error", processing_error: "The document could not be read. Please ensure it is a valid .docx or .pdf file containing readable text." }).eq("id", upload_id);
      triggerEmail(upload_id);
      return jsonResponse({ status: "error", error: "Insufficient text extracted" });
    }

    const tier = (upload.tier || "one_time_scan") as string;
    const charLimit = TIER_CHAR_LIMITS[tier] ?? DEFAULT_CHAR_LIMIT;
    if (fullText.length > charLimit) {
      const limitPages = Math.round(charLimit / 2500);
      await supabase.from("compliance_uploads").update({ status: "error", processing_error: `Document exceeds the ${limitPages}-page limit for your plan.` }).eq("id", upload_id);
      triggerEmail(upload_id);
      return jsonResponse({ status: "error", error: "Document exceeds tier limit" });
    }

    // v25: Pre-screen timeout reduced from 30s to 15s
    const screen = await preScreenDocument(fullText, upload.document_type);
    if (!screen.inScope) {
      const typeLabels: Record<string, string> = { b2b_contract: "a business-to-business commercial contract", property_agreement: "a property or tenancy agreement", financial_document: "a financial or loan document", legal_correspondence: "legal correspondence", corporate_document: "a corporate governance document", internal_technical_document: "an internal technical document", unreadable: "an unreadable or empty document" };
      const typeLabel = typeLabels[screen.detectedType] || "a document outside the scope of UK employment law";
      await supabase.from("compliance_uploads").update({ status: "out_of_scope", processing_error: `Document identified as ${typeLabel}. Ailane analyses employment contracts, staff handbooks, and workplace policies only. ${screen.reason}`, overall_score: 0 }).eq("id", upload_id);
      triggerEmail(upload_id);
      return jsonResponse({ upload_id, status: "out_of_scope", detected_type: screen.detectedType, engine_version: ENGINE_VERSION });
    }
    console.log(`[${ENGINE_VERSION}] Pre-screen passed: ${screen.detectedType}`);

    const rawDocType = upload.document_type || "employment_contract";
    const normalisedDocType = DOC_TYPE_MAP[rawDocType] ?? rawDocType;
    console.log(`[${ENGINE_VERSION}] doc_type: ${rawDocType} → normalised: ${normalisedDocType}`);

    const { data: currentReqs, error: reqErr } = await supabase
      .from("regulatory_requirements").select("*")
      .in("applies_to", [normalisedDocType, "both"])
      .is("effective_to", null)
      .eq("is_forward_requirement", false);
    if (reqErr || !currentReqs?.length) throw new Error(`No requirements found for type '${normalisedDocType}': ${reqErr?.message}`);
    console.log(`[${ENGINE_VERSION}] ${currentReqs.length} current requirements loaded`);

    const { data: forwardReqs } = await supabase
      .from("regulatory_requirements").select("*")
      .in("applies_to", [normalisedDocType, "both"])
      .is("effective_to", null)
      .eq("is_forward_requirement", true);
    const fwdReqs = forwardReqs || [];
    console.log(`[${ENGINE_VERSION}] ${fwdReqs.length} forward requirements loaded`);

    const reqMap = new Map(currentReqs.map((r) => [r.id, r]));
    const reqNameMap = new Map(currentReqs.map((r) => [r.requirement_name.toLowerCase().replace(/[^a-z0-9 ]/g, "").trim(), r]));

    const mid = Math.ceil(currentReqs.length / 2);
    const batchA = currentReqs.slice(0, mid);
    const batchB = currentReqs.slice(mid);

    const buildBatchPrompt = async (batch: typeof currentReqs, label: string): Promise<{ prompt: string; groundingByReq: Map<string, GroundingRef[]> }> => {
      const groundingByReq = new Map<string, GroundingRef[]>();
      const groundingPromises = batch.map(async (r) => {
        const refs = await retrieveGrounding(supabase, r.id, 3, 2);
        groundingByReq.set(r.id, refs);
      });
      await Promise.all(groundingPromises);

      const reqList = batch.map((r, i) => {
        const refs = groundingByReq.get(r.id) || [];
        const groundingBlock = refs.length > 0
          ? "\n   KL GROUNDING (top ranked by semantic similarity):\n" +
            refs.map((g, j) => `     [${j + 1}] (${g.source}) ${g.citation}: ${g.snippet}`).join("\n")
          : "";
        return `${i + 1}. requirement_id="${r.id}" | REQUIREMENT: ${r.requirement_name} | STATUTORY BASIS: ${r.statutory_basis} | ${r.mandatory ? "MANDATORY — absence is critical" : "Recommended"} | DESCRIPTION: ${r.description}${groundingBlock}`;
      }).join("\n\n");

      const prompt = `Analyse this ${normalisedDocType} against ${batch.length} UK employment law requirements (Batch ${label} of 2).\n\nFor EACH requirement you are given KL GROUNDING — the most relevant statutory provisions and cases from the Ailane Knowledge Library, ranked by semantic similarity. Use these as reference when assessing the clause. You may cite them in your finding_detail (by square-bracket index) where they support your analysis.\n\nReturn EXACTLY ${batch.length} JSON objects in the SAME ORDER as the numbered list below. Use the exact requirement_id string provided for each item.\n\nFULL DOCUMENT TEXT:\n${fullText}\n\n---\n\nREQUIREMENTS WITH GROUNDING (return one object per item, in order):\n${reqList}`;

      return { prompt, groundingByReq };
    };

    const fwdReqMap = new Map(fwdReqs.map((r) => [r.id, r]));
    const fwdReqNameMap = new Map(fwdReqs.map((r) => [r.requirement_name.toLowerCase().replace(/[^a-z0-9 ]/g, "").trim(), r]));

    const buildForwardPrompt = async (): Promise<{ prompt: string; groundingByReq: Map<string, GroundingRef[]> }> => {
      const groundingByReq = new Map<string, GroundingRef[]>();
      const groundingPromises = fwdReqs.map(async (r) => {
        const refs = await retrieveGrounding(supabase, r.id, 3, 2);
        groundingByReq.set(r.id, refs);
      });
      await Promise.all(groundingPromises);

      const reqList = fwdReqs.map((r, i) => {
        const refs = groundingByReq.get(r.id) || [];
        const groundingBlock = refs.length > 0
          ? "\n   KL GROUNDING (top ranked by semantic similarity):\n" +
            refs.map((g, j) => `     [${j + 1}] (${g.source}) ${g.citation}: ${g.snippet}`).join("\n")
          : "";
        return `${i + 1}. requirement_id="${r.id}" | FUTURE REQUIREMENT: ${r.requirement_name} | STATUTORY BASIS: ${r.statutory_basis} | EXPECTED COMMENCEMENT: ${r.effective_from || 'TBC'} | STATUS: ${r.commencement_status} | ${r.mandatory ? "Will be MANDATORY" : "Recommended"} | DESCRIPTION: ${r.description}${groundingBlock}`;
      }).join("\n\n");

      const prompt = `Analyse this ${normalisedDocType} for FORWARD EXPOSURE against ${fwdReqs.length} forthcoming UK employment law requirements (Employment Rights Act 2025 provisions not yet in force).\n\nFor EACH requirement you are given KL GROUNDING — the most relevant statutory provisions and cases from the Ailane Knowledge Library, ranked by semantic similarity. Use these as reference when assessing the clause. You may cite them in your finding_detail (by square-bracket index) where they support your analysis.\n\nReturn EXACTLY ${fwdReqs.length} JSON objects in the SAME ORDER as the numbered list below. Use the exact requirement_id string provided for each item.\n\nFULL DOCUMENT TEXT:\n${fullText}\n\n---\n\nFORTHCOMING REQUIREMENTS WITH GROUNDING (return one object per item, in order):\n${reqList}`;

      return { prompt, groundingByReq };
    };

    const tBatch = Date.now();
    console.log(`[${ENGINE_VERSION}] Firing parallel: A(${batchA.length}) B(${batchB.length}) F(${fwdReqs.length}) — ${fullText.length} chars...`);

    // v26: 3-model fallback with per-model timeouts [45_000, 35_000, 25_000] = 105s worst case per batch.
    // Parallel A/B/F run concurrently; total wall clock <= 120s (< 150s cap).
    // Grounding is retrieved via pgvector RPCs inside buildBatchPrompt / buildForwardPrompt
    // (pre-computed embeddings only; no Voyage at runtime per DPIA §4.2).
    const buildA = await buildBatchPrompt(batchA, "A");
    const buildB = await buildBatchPrompt(batchB, "B");
    const buildF = fwdReqs.length > 0 ? await buildForwardPrompt() : null;
    const groundingByReqA = buildA.groundingByReq;
    const groundingByReqB = buildB.groundingByReq;
    const groundingByReqF = buildF?.groundingByReq ?? new Map<string, GroundingRef[]>();

    const promises: Promise<any>[] = [
      callClaude(ANALYSIS_SYSTEM_PROMPT, buildA.prompt, 6000, 55_000, BATCH_MODELS, BATCH_TIMEOUTS_MS),
      callClaude(ANALYSIS_SYSTEM_PROMPT, buildB.prompt, 6000, 55_000, BATCH_MODELS, BATCH_TIMEOUTS_MS),
    ];
    if (buildF) promises.push(callClaude(FORWARD_SYSTEM_PROMPT, buildF.prompt, 6000, 55_000, BATCH_MODELS, BATCH_TIMEOUTS_MS));

    const settled = await Promise.allSettled(promises);
    const [settledA, settledB] = settled;
    const settledF = settled.length > 2 ? settled[2] : null;

    console.log(`[${ENGINE_VERSION}] Done ${Date.now() - tBatch}ms | A:${settledA.status} B:${settledB.status}${settledF ? ` F:${settledF.status}` : ''}`);

    if (settledA.status === "rejected" && settledB.status === "rejected") {
      throw new Error(`Both current batches failed. A: ${(settledA as PromiseRejectedResult).reason?.message} | B: ${(settledB as PromiseRejectedResult).reason?.message}`);
    }

    const modelA = settledA.status === "fulfilled" ? (settledA as PromiseFulfilledResult<any>).value.model : "failed";
    const modelB = settledB.status === "fulfilled" ? (settledB as PromiseFulfilledResult<any>).value.model : "failed";
    const modelF = settledF?.status === "fulfilled" ? (settledF as PromiseFulfilledResult<any>).value.model : "n/a";
    const primaryModel = modelA !== "failed" ? modelA : modelB;

    const rawA: any[] = settledA.status === "fulfilled" ? (() => { try { return parseAnalysisResult((settledA as PromiseFulfilledResult<any>).value.text, "A"); } catch (e) { console.error(`[${ENGINE_VERSION}] Parse A: ${(e as Error).message}`); return []; } })() : [];
    const rawB: any[] = settledB.status === "fulfilled" ? (() => { try { return parseAnalysisResult((settledB as PromiseFulfilledResult<any>).value.text, "B"); } catch (e) { console.error(`[${ENGINE_VERSION}] Parse B: ${(e as Error).message}`); return []; } })() : [];
    const rawF: any[] = settledF?.status === "fulfilled" ? (() => { try { return parseAnalysisResult((settledF as PromiseFulfilledResult<any>).value.text, "F"); } catch (e) { console.error(`[${ENGINE_VERSION}] Parse F: ${(e as Error).message}`); return []; } })() : [];

    const matchedA = matchRequirements(rawA, batchA, reqMap, reqNameMap, "A");
    const matchedB = matchRequirements(rawB, batchB, reqMap, reqNameMap, "B");
    const allMatched = [...matchedA, ...matchedB];
    console.log(`[${ENGINE_VERSION}] Current matched: ${allMatched.length} of ${currentReqs.length}`);

    const matchedF = matchRequirements(rawF, fwdReqs, fwdReqMap, fwdReqNameMap, "F");
    console.log(`[${ENGINE_VERSION}] Forward matched: ${matchedF.length} of ${fwdReqs.length}`);

    const pricing = await fetchModelPricing(supabase);

    const costA = settledA.status === "fulfilled"
      ? computeCallCostUsd((settledA as PromiseFulfilledResult<any>).value.model,
                           (settledA as PromiseFulfilledResult<any>).value.inputTokens,
                           (settledA as PromiseFulfilledResult<any>).value.outputTokens,
                           pricing) : 0;
    const costB = settledB.status === "fulfilled"
      ? computeCallCostUsd((settledB as PromiseFulfilledResult<any>).value.model,
                           (settledB as PromiseFulfilledResult<any>).value.inputTokens,
                           (settledB as PromiseFulfilledResult<any>).value.outputTokens,
                           pricing) : 0;
    const costF = settledF?.status === "fulfilled"
      ? computeCallCostUsd((settledF as PromiseFulfilledResult<any>).value.model,
                           (settledF as PromiseFulfilledResult<any>).value.inputTokens,
                           (settledF as PromiseFulfilledResult<any>).value.outputTokens,
                           pricing) : 0;

    const perFindingCostA = matchedA.length > 0 ? costA / matchedA.length : 0;
    const perFindingCostB = matchedB.length > 0 ? costB / matchedB.length : 0;
    const perFindingCostF = matchedF.length > 0 ? costF / matchedF.length : 0;

    for (const { ar, req } of allMatched) {
      const severity = validSev.includes(ar.severity) ? ar.severity : "minor";
      const reqGrounding = (groundingByReqA.get(req.id) ?? groundingByReqB.get(req.id)) || null;
      const perFindingCost = matchedA.some((m) => m.req.id === req.id) ? perFindingCostA : perFindingCostB;
      findings.push({
        upload_id, clause_text: (ar.clause_text || "[Not analysed]").substring(0, 1000), clause_category: req.category, statutory_ref: req.statutory_basis, requirement_id: req.id, severity,
        finding_detail: (ar.finding_detail || `${req.requirement_name}: ${severity}`).substring(0, 2000),
        remediation: severity !== "compliant" ? (ar.remediation || `Review against ${req.statutory_basis}.`).substring(0, 2000) : null,
        pillar_mapping: req.pillar_mapping, pillar_mapping_type: "primary", engine_version: ENGINE_VERSION,
        is_forward_looking: false, forward_effective_date: null, forward_source_act: null,
        grounding_refs: reqGrounding && reqGrounding.length > 0 ? reqGrounding : null,
        model_cost_usd: perFindingCost || null,
      });
      coveredIds.add(req.id);
    }

    const gapFilled: string[] = [];
    for (const req of currentReqs) {
      if (!coveredIds.has(req.id)) {
        gapFilled.push(req.requirement_name);
        findings.push({
          upload_id, clause_text: "[Not returned in analysis]", clause_category: req.category, statutory_ref: req.statutory_basis, requirement_id: req.id, severity: "minor",
          finding_detail: `${req.requirement_name} was not returned in the analysis output. Manual review recommended against ${req.statutory_basis}.`,
          remediation: `Manually verify compliance with ${req.requirement_name} under ${req.statutory_basis}.`,
          pillar_mapping: req.pillar_mapping, pillar_mapping_type: "primary", engine_version: ENGINE_VERSION,
          is_forward_looking: false, forward_effective_date: null, forward_source_act: null,
          grounding_refs: null, model_cost_usd: null,
        });
      }
    }
    if (gapFilled.length > 0) console.warn(`[${ENGINE_VERSION}] Gap-filled ${gapFilled.length}: ${gapFilled.join(", ")}`);

    const forwardFindings: Finding[] = [];
    for (const { ar, req } of matchedF) {
      const severity = validSev.includes(ar.severity) ? ar.severity : "minor";
      const reqGrounding = groundingByReqF.get(req.id) || null;
      forwardFindings.push({
        upload_id, clause_text: (ar.clause_text || "[No existing clause]").substring(0, 1000), clause_category: req.category, statutory_ref: req.statutory_basis, requirement_id: req.id, severity,
        finding_detail: (ar.finding_detail || `Forward exposure: ${req.requirement_name}`).substring(0, 2000),
        remediation: severity !== "compliant" ? (ar.remediation || `Review ahead of ${req.effective_from}.`).substring(0, 2000) : null,
        pillar_mapping: req.pillar_mapping, pillar_mapping_type: "primary", engine_version: ENGINE_VERSION,
        is_forward_looking: true,
        forward_effective_date: req.effective_from || null,
        forward_source_act: req.source_act || "Employment Rights Act 2025",
        grounding_refs: reqGrounding && reqGrounding.length > 0 ? reqGrounding : null,
        model_cost_usd: perFindingCostF || null,
      });
    }

    const fwdCoveredIds = new Set(matchedF.map(m => m.req.id));
    for (const req of fwdReqs) {
      if (!fwdCoveredIds.has(req.id)) {
        forwardFindings.push({
          upload_id, clause_text: "[Not returned in forward analysis]", clause_category: req.category, statutory_ref: req.statutory_basis, requirement_id: req.id, severity: "minor",
          finding_detail: `Forward exposure assessment for ${req.requirement_name} was not returned. Manual review recommended ahead of expected commencement on ${req.effective_from || 'TBC'}.`,
          remediation: `Review document provisions against ${req.requirement_name} (${req.statutory_basis}) before ${req.effective_from || 'commencement'}.`,
          pillar_mapping: req.pillar_mapping, pillar_mapping_type: "primary", engine_version: ENGINE_VERSION,
          is_forward_looking: true,
          forward_effective_date: req.effective_from || null,
          forward_source_act: req.source_act || "Employment Rights Act 2025",
          grounding_refs: null, model_cost_usd: null,
        });
      }
    }

    console.log(`[${ENGINE_VERSION}] Forward findings: ${forwardFindings.length} (${forwardFindings.filter(f => f.severity === 'critical').length} critical, ${forwardFindings.filter(f => f.severity === 'major').length} major)`);

    const allFindings = [...findings, ...forwardFindings];

    const sparseRatio = currentReqs.length > 0 ? gapFilled.length / currentReqs.length : 0;
    const isSparse = sparseRatio > SPARSE_THRESHOLD;
    if (isSparse) console.warn(`[${ENGINE_VERSION}] SPARSE REPORT: gap_filled=${gapFilled.length}/${currentReqs.length} (${Math.round(sparseRatio * 100)}%)`);

    const critCount = findings.filter((f) => f.severity === "critical").length;
    const fwdCritCount = forwardFindings.filter((f) => f.severity === "critical").length;
    console.log(`[${ENGINE_VERSION}] ${findings.length} current findings (${critCount} critical) + ${forwardFindings.length} forward findings (${fwdCritCount} critical fwd) via ${primaryModel}`);

    for (let i = 0; i < allFindings.length; i += 5) {
      const { error: insErr } = await supabase.from("compliance_findings").insert(allFindings.slice(i, i + 5));
      if (insErr) console.error(`[${ENGINE_VERSION}] Insert batch ${i}:`, insErr.message);
    }

    const { overallScore, translatedPillarScore } = computeScore(findings);

    const finalStatus = isSparse ? "sparse_report" : "complete";
    const sparseError = isSparse ? `Analysis produced insufficient findings (${gapFilled.length} of ${currentReqs.length} requirements not returned).` : null;

    await supabase.from("compliance_uploads").update({
      status: finalStatus,
      overall_score: overallScore,
      translated_pillar_score: translatedPillarScore,
      ...(sparseError ? { processing_error: sparseError } : {}),
    }).eq("id", upload_id);

    triggerEmail(upload_id);

    const currentSummary = findings.reduce((a, f) => { a[f.severity] = (a[f.severity] || 0) + 1; return a; }, {} as Record<string, number>);
    const forwardSummary = forwardFindings.reduce((a, f) => { a[f.severity] = (a[f.severity] || 0) + 1; return a; }, {} as Record<string, number>);

    console.log(`[${ENGINE_VERSION}] ✓ ${finalStatus.toUpperCase()} score=${overallScore} | current=${JSON.stringify(currentSummary)} | forward=${JSON.stringify(forwardSummary)} | ${modelA}+${modelB}+${modelF}`);

    return jsonResponse({
      upload_id,
      status: finalStatus,
      overall_score: overallScore,
      translated_pillar_score: translatedPillarScore,
      findings_total: findings.length,
      forward_findings_total: forwardFindings.length,
      summary: currentSummary,
      forward_summary: forwardSummary,
      model_used: `${modelA}+${modelB}+${modelF}`,
      primary_model: primaryModel,
      analysis_time_ms: Date.now() - tBatch,
      gap_filled: gapFilled.length,
      sparse_ratio: Math.round(sparseRatio * 100),
      engine_version: ENGINE_VERSION,
      total_cost_usd: Math.round((costA + costB + costF) * 1_000_000) / 1_000_000,
      grounding_coverage: Math.round(
        (allMatched.filter((m) => ((groundingByReqA.get(m.req.id) ?? groundingByReqB.get(m.req.id))?.length ?? 0) > 0).length /
         Math.max(allMatched.length, 1)) * 100
      ),
    });
  } catch (e) {
    const msg = (e as Error).message || "Unknown error";
    console.error(`[${ENGINE_VERSION}] FATAL upload_id=${upload_id}: ${msg}`);
    if (upload_id) {
      const sc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
      await sc.from("compliance_uploads").update({ status: "error", processing_error: msg.substring(0, 500) }).eq("id", upload_id);
      triggerEmail(upload_id);
    }
    return jsonResponse({ error: msg }, 500);
  }
});
