// AILANE-CC-BRIEF-EILEEN-NEXUS-002-PART-A §2.3
// Edge Function: eileen-nexus-intel v3 — Nexus live-data passthrough.
// Slug renamed from brief text per Chairman ruling CIE-PAR-A-RULING-003
// (Path C): v2 eileen-landing-intel remains ACTIVE serving the 27-field
// flat ticker payload; this new slug serves the §0.6 Nexus contract to
// avoid a breaking shape change.
//
// Authority: AMD-058 Art. 13.1 (Landing Page Hero Nexus), Art. 17
// (Canonical Edge Functions).
//
// Deploy flag: verify_jwt = false (public read-only endpoint; rate-limited
// by IP). Source of truth: this file. Do not edit in Dashboard without
// backfilling here (RULE 13).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "https://ailane.ai",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
  "Access-Control-Max-Age": "86400",
};

async function checkRateLimit(
  supabase: any,
  ip: string,
  windowMinutes: number,
  maxRequests: number,
): Promise<boolean> {
  try {
    const windowStart = new Date(
      Date.now() - windowMinutes * 60 * 1000,
    ).toISOString();
    const { count } = await supabase
      .from("rate_limits")
      .select("*", { count: "exact", head: true })
      .eq("ip_address", ip)
      .eq("function_name", "eileen-nexus-intel")
      .gte("created_at", windowStart);
    if ((count ?? 0) >= maxRequests) return false;
    await supabase.from("rate_limits").insert({
      ip_address: ip,
      function_name: "eileen-nexus-intel",
      created_at: new Date().toISOString(),
    });
    return true;
  } catch (e) {
    console.warn("Rate limit check failed, allowing request:", e);
    return true;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "GET") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error(
      "MISSING SECRETS:",
      !SUPABASE_URL ? "SUPABASE_URL" : "",
      !SUPABASE_SERVICE_ROLE_KEY ? "SUPABASE_SERVICE_ROLE_KEY" : "",
    );
    return new Response(
      JSON.stringify({ error: "Server configuration error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const ip =
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const allowed = await checkRateLimit(supabase, ip, 1, 30);
  if (!allowed) {
    return new Response(JSON.stringify({ error: "Rate limit exceeded" }), {
      status: 429,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // Single read from the umbrella view (service_role bypasses the
    // anon/authenticated REVOKEs from §2.1-patch).
    const { data, error } = await supabase
      .from("vw_eileen_nexus_intel")
      .select("categories, instruments, relationships, snapshot_at")
      .single();

    if (error || !data) {
      console.error("eileen-nexus-intel view read failed:", error);
      return new Response(
        JSON.stringify({ error: "Intelligence retrieval failed" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // §0.6 contract — exactly five top-level keys, no extras.
    // snapshot_at (MV column, snake_case) → snapshotAt (contract key, camelCase).
    const payload = {
      categories: data.categories ?? [],
      instruments: data.instruments ?? [],
      relationships: data.relationships ?? [],
      snapshotAt: data.snapshot_at,
      version: "v3",
    };

    return new Response(JSON.stringify(payload), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
        // 5 minutes — matches §2.2 pg_cron refresh cadence; do not
        // over-cache past staleness.
        "Cache-Control": "public, max-age=300",
      },
    });
  } catch (err) {
    console.error("eileen-nexus-intel error:", err);
    return new Response(
      JSON.stringify({ error: "Intelligence retrieval failed" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
