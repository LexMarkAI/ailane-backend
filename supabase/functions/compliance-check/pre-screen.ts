// AILANE-CC-BRIEF-HBCHECK-001 — Pre-Screen Document Classification
// Source: AILANE-SPEC-CCA-001 v1.0, §6.1 + HBCHECK-001 §5

export interface PreScreenResult {
  inScope: boolean;
  detectedType: 'employment_contract' | 'staff_handbook' | 'policy_document' | 'unknown';
  reason: string;
}

const PRE_SCREEN_SYSTEM_PROMPT = `You are a document classification engine for Ailane, a UK employment law compliance platform.

Your task: Given a document excerpt and the user's declared document type, determine:

1. Whether this document is in scope (an employment-related document)
2. What type of document it actually is (regardless of what the user declared)

CLASSIFICATION SIGNALS:

STAFF HANDBOOK (detectedType = "staff_handbook"):
* Multiple distinct policy sections with separate headings
* Procedure headings (Disciplinary, Grievance, Sickness, Leave, etc.)
* ACAS Code of Practice language or references
* Organisational scope language ("all employees", "this handbook applies to", "company policy")
* Table of contents covering multiple employment policy domains
* References to multiple statutory instruments across different employment law areas
* Section numbering suggesting a multi-chapter document
* Absence of individual employee name / specific salary / specific start date
* Terms like "handbook", "employee guide", "company policies"

EMPLOYMENT CONTRACT (detectedType = "employment_contract"):
* Named employer AND named employee/worker (two specific parties)
* Specific start date and job title for an individual
* Specific remuneration (salary, hourly rate) and hours for an individual
* Written statement of particulars structure (ERA 1996 s.1 pattern)
* Individual terms and conditions focus
* Notice period specific to this individual
* Signatures or signature blocks for both parties

POLICY DOCUMENT (detectedType = "policy_document"):
* Single-topic focus (e.g. only about data protection, only about flexible working)
* Named policy owner or approver
* Review date and version reference
* Scope clause defining who the policy applies to
* Not a multi-domain handbook — focused on one employment policy area

OUT OF SCOPE (inScope = false):
* Commercial contracts (not employment-related)
* Non-UK employment documents (different jurisdiction)
* CVs, cover letters, job advertisements
* Financial documents, invoices, receipts
* Personal documents unrelated to employment

TIE-BREAKER RULE: If the document is ambiguous between a contract and a handbook (e.g. a combined document), classify as "staff_handbook" — the handbook requirement library is a superset that will catch contract-relevant findings too.

Respond with ONLY a valid JSON object:
{
  "in_scope": true | false,
  "detected_type": "employment_contract" | "staff_handbook" | "policy_document" | "unknown",
  "reason": "Brief explanation of classification decision"
}`;

export async function preScreen(
  docText: string,
  declaredType: string,
  anthropicApiKey: string
): Promise<PreScreenResult> {
  const sample = docText.length > 3000 ? docText.substring(0, 3000) : docText;

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': anthropicApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 300,
        messages: [
          {
            role: 'user',
            content: `Declared document type: "${declaredType}"\n\nDocument text (first 3,000 characters):\n${sample}`,
          },
        ],
        system: PRE_SCREEN_SYSTEM_PROMPT,
      }),
    });

    if (!response.ok) {
      console.warn(`[preScreen] API returned ${response.status}, defaulting to in-scope`);
      return { inScope: true, detectedType: 'unknown', reason: 'Pre-screen unavailable.' };
    }

    const data = await response.json();
    const text = data.content?.[0]?.text?.trim() || '';
    const cleaned = text.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, '').trim();
    const parsed = JSON.parse(cleaned);

    console.log(`[preScreen] in_scope=${parsed.in_scope} detected=${parsed.detected_type}`);

    return {
      inScope: parsed.in_scope === true,
      detectedType: parsed.detected_type || 'unknown',
      reason: parsed.reason || 'Classification complete.',
    };
  } catch (e) {
    console.warn(`[preScreen] Failed (${(e as Error).message}), defaulting to in-scope`);
    return { inScope: true, detectedType: 'unknown', reason: 'Pre-screen unavailable; proceeding with analysis.' };
  }
}
