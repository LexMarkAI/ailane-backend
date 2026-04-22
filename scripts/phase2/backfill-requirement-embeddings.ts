// backfill-requirement-embeddings.ts
// ONE-TIME job: compute voyage-law-2 embeddings for all regulatory_requirements rows.
// Idempotent: only processes rows WHERE embedding IS NULL.
// Run: deno run --allow-env --allow-net --allow-read scripts/phase2/backfill-requirement-embeddings.ts

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const VOYAGE_API_KEY = Deno.env.get("VOYAGE_API_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !VOYAGE_API_KEY) {
  console.error("Missing env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, VOYAGE_API_KEY");
  Deno.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface Requirement {
  id: string;
  requirement_name: string;
  statutory_basis: string;
  description: string;
}

async function embedOne(text: string): Promise<number[]> {
  const r = await fetch("https://api.voyageai.com/v1/embeddings", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${VOYAGE_API_KEY}`,
    },
    body: JSON.stringify({
      model: "voyage-law-2",
      input: [text],
      input_type: "document",
    }),
  });
  if (!r.ok) {
    const body = await r.text();
    throw new Error(`Voyage API ${r.status}: ${body.slice(0, 300)}`);
  }
  const data = await r.json();
  const emb = data?.data?.[0]?.embedding;
  if (!Array.isArray(emb) || emb.length !== 1024) {
    throw new Error(`Voyage returned invalid embedding (length=${emb?.length})`);
  }
  return emb;
}

async function run() {
  console.log("--- regulatory_requirements embedding backfill ---");

  const { data: pending, error } = await supabase
    .from("regulatory_requirements")
    .select("id, requirement_name, statutory_basis, description")
    .is("embedding", null);

  if (error) {
    console.error("Fetch failed:", error.message);
    Deno.exit(1);
  }

  console.log(`Pending rows: ${pending?.length ?? 0}`);
  if (!pending || pending.length === 0) {
    console.log("Nothing to do. Exiting.");
    return;
  }

  let success = 0;
  let failed = 0;
  const failures: string[] = [];

  for (const r of pending as Requirement[]) {
    const text = [
      r.requirement_name ?? "",
      r.statutory_basis ?? "",
      r.description ?? "",
    ].filter(s => s.length > 0).join(" — ");

    try {
      const emb = await embedOne(text);
      const embLiteral = `[${emb.join(",")}]`;
      const { error: updErr } = await supabase
        .from("regulatory_requirements")
        .update({ embedding: embLiteral, updated_at: new Date().toISOString() })
        .eq("id", r.id);

      if (updErr) {
        failed++;
        failures.push(`${r.id}: update failed: ${updErr.message}`);
        console.error(`FAIL ${r.id}: ${updErr.message}`);
      } else {
        success++;
        console.log(`OK   ${r.id.slice(0, 8)} (${r.requirement_name.slice(0, 48)}...)`);
      }
    } catch (e) {
      failed++;
      failures.push(`${r.id}: ${(e as Error).message}`);
      console.error(`FAIL ${r.id}: ${(e as Error).message}`);
    }

    // Voyage rate-limit courtesy delay (50 ms between calls)
    await new Promise(resolve => setTimeout(resolve, 50));
  }

  console.log("");
  console.log(`--- Complete: ${success} success, ${failed} failed ---`);
  if (failures.length > 0) {
    console.log("Failures:");
    failures.forEach(f => console.log(`  ${f}`));
    Deno.exit(1);
  }
}

await run();
