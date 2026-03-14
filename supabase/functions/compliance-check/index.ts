// AILANE-CC-BRIEF-HBCHECK-001 — Compliance Check Edge Function
// Four-layer document-type-aware compliance analysis engine
//
// INTEGRATION NOTE FOR CC:
// This file is a REFERENCE IMPLEMENTATION. If an existing compliance-check
// Edge Function is already deployed, you should MERGE the new capabilities
// (preScreen routing, buildSystemPrompt, handbook library) into the existing
// function rather than replacing it wholesale.
//
// The sections marked "ADAPT TO EXISTING" indicate where you must match
// the existing function's patterns for Supabase client init, file retrieval,
// text extraction, and result storage.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { preScreen } from './pre-screen.ts';
import { buildSystemPrompt } from './prompt-layers.ts';

// ─── CORS ────────────────────────────────────────────────────────────
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  try {
    // ─── ENVIRONMENT ─────────────────────────────────────────────────
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
    const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')!;

    const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // ─── REQUEST PARSING ─────────────────────────────────────────────
    // ADAPT TO EXISTING: Match your current request parsing pattern.
    // The function receives an upload_id and retrieves the document
    // from storage / database.
    const { upload_id } = await req.json();

    if (!upload_id) {
      return new Response(
        JSON.stringify({ error: 'upload_id is required' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // ─── UPDATE STATUS: PROCESSING ─────────────────────────────────
    // ADAPT TO EXISTING: Match your table name and column names.
    await sb.from('compliance_uploads').update({
      status: 'processing',
      updated_at: new Date().toISOString(),
    }).eq('id', upload_id);

    // ─── RETRIEVE DOCUMENT TEXT ────────────────────────────────────
    // ADAPT TO EXISTING: Your current function already handles:
    //   1. Fetching the upload record from the database
    //   2. Downloading the file from Supabase Storage
    //   3. Extracting text (DOCX via JSZip, PDF handling)
    //   4. Getting the declared document_type from the upload record
    //
    // Replace this placeholder with your existing retrieval logic.
    const { data: upload, error: uploadErr } = await sb
      .from('compliance_uploads')
      .select('*')
      .eq('id', upload_id)
      .single();

    if (uploadErr || !upload) {
      throw new Error(`Upload not found: ${upload_id}`);
    }

    const declaredType = upload.document_type || 'contract';
    const docText = upload.extracted_text || '';
    // ADAPT TO EXISTING: If text extraction happens here (not at upload
    // time), keep your existing extraction logic and store the result
    // in docText.

    if (!docText || docText.trim().length < 50) {
      await sb.from('compliance_uploads').update({
        status: 'error',
        processing_error: 'Document text extraction failed or document is too short.',
        updated_at: new Date().toISOString(),
      }).eq('id', upload_id);

      return new Response(
        JSON.stringify({ error: 'Document text extraction failed' }),
        { status: 422, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // ═══════════════════════════════════════════════════════════════════
    // NEW: PRE-SCREEN & DOCUMENT TYPE ROUTING
    // This is the core addition from HBCHECK-001
    // ═══════════════════════════════════════════════════════════════════

    // Step 1: Pre-screen for scope and document type detection
    const { inScope, detectedType, reason } = await preScreen(
      docText,
      declaredType,
      ANTHROPIC_API_KEY
    );

    console.log(`[compliance-check] upload=${upload_id} declared=${declaredType} detected=${detectedType} inScope=${inScope}`);

    // Step 2: Handle out-of-scope documents
    if (!inScope) {
      await sb.from('compliance_uploads').update({
        status: 'out_of_scope',
        processing_error: reason,
        detected_type: detectedType,
        updated_at: new Date().toISOString(),
      }).eq('id', upload_id);

      return new Response(
        JSON.stringify({
          status: 'out_of_scope',
          reason,
          detected_type: detectedType,
        }),
        { status: 200, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // Step 3: Build the four-layer system prompt based on detected type
    const systemPrompt = buildSystemPrompt(detectedType as any);

    // Step 4: Store the detected type on the upload record
    // ADAPT TO EXISTING: If your table doesn't have a detected_type
    // column, add it via migration or remove this update.
    await sb.from('compliance_uploads').update({
      detected_type: detectedType,
      updated_at: new Date().toISOString(),
    }).eq('id', upload_id);

    // ═══════════════════════════════════════════════════════════════════
    // MAIN ANALYSIS — Anthropic API Call
    // ═══════════════════════════════════════════════════════════════════

    const userMessage = `Document type declared by user: "${declaredType}"
Document type detected by pre-screen: "${detectedType}"
Reason: ${reason}

DOCUMENT TEXT:
${docText}`;

    console.log(`[compliance-check] Calling Anthropic API for upload=${upload_id}, prompt length=${systemPrompt.length + userMessage.length}`);

    const apiResponse = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 8000,
        messages: [{ role: 'user', content: userMessage }],
        system: systemPrompt,
      }),
    });

    if (!apiResponse.ok) {
      const errText = await apiResponse.text();
      console.error(`[compliance-check] Anthropic API error: ${apiResponse.status} ${errText}`);
      throw new Error(`Anthropic API returned ${apiResponse.status}`);
    }

    const apiData = await apiResponse.json();
    const rawText = apiData.content?.[0]?.text || '';

    // Parse the JSON response
    let analysisResult;
    try {
      const cleaned = rawText.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, '').trim();
      analysisResult = JSON.parse(cleaned);
    } catch (parseErr) {
      console.error(`[compliance-check] JSON parse failed for upload=${upload_id}:`, parseErr);
      console.error(`[compliance-check] Raw response:`, rawText.substring(0, 500));
      throw new Error('AI response was not valid JSON');
    }

    // ═══════════════════════════════════════════════════════════════════
    // STORE RESULTS
    // ADAPT TO EXISTING: Match your current result storage pattern.
    // ═══════════════════════════════════════════════════════════════════

    const {
      overall_score,
      summary,
      finding_counts,
      findings,
      document_type: resultDocType,
    } = analysisResult;

    await sb.from('compliance_uploads').update({
      status: 'complete',
      overall_score,
      summary,
      finding_counts,
      detected_type: resultDocType || detectedType,
      updated_at: new Date().toISOString(),
    }).eq('id', upload_id);

    // Store individual findings
    // ADAPT TO EXISTING: Match your current findings storage pattern.
    // If findings are stored in a separate table, use that table name.
    // If they're stored as a JSON column on the upload record, adjust.
    if (findings && Array.isArray(findings)) {
      const findingRows = findings.map((f: any, idx: number) => ({
        upload_id,
        requirement_id: f.requirement_id || `FINDING-${idx + 1}`,
        clause_ref: f.clause_ref || null,
        severity: f.severity,
        finding: f.finding,
        statutory_reference: f.statutory_reference || null,
        remediation: f.remediation || null,
        sort_order: idx,
      }));

      // ADAPT TO EXISTING: Your table name may differ
      const { error: findingsErr } = await sb
        .from('compliance_findings')
        .insert(findingRows);

      if (findingsErr) {
        console.error(`[compliance-check] Findings insert error:`, findingsErr);
        // Non-fatal — the upload is marked complete even if findings
        // storage fails. The raw result is in the upload record.
      }
    }

    console.log(`[compliance-check] Complete: upload=${upload_id} score=${overall_score} type=${resultDocType || detectedType} findings=${findings?.length || 0}`);

    // ─── TRIGGER EMAIL & PDF GENERATION ──────────────────────────────
    // ADAPT TO EXISTING: If your current function triggers
    // send-report-email and/or generate-report-pdf, keep that logic.
    // It typically runs as a fire-and-forget fetch to the other
    // Edge Functions after storing the results.

    return new Response(
      JSON.stringify({
        status: 'complete',
        upload_id,
        overall_score,
        summary,
        finding_counts,
        document_type: resultDocType || detectedType,
        findings_count: findings?.length || 0,
      }),
      { status: 200, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    console.error(`[compliance-check] Fatal error:`, err);

    return new Response(
      JSON.stringify({ error: (err as Error).message || 'Internal server error' }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  }
});
