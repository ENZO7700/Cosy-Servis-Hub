import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type SlotFillerRequest = {
  providerId: string;
  cancelledBooking?: {
    scheduledAt?: string;
    serviceName?: string;
    priceAmount?: number;
  };
  candidateLimit?: number;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function draftMessage(name: string, serviceName: string, scheduledAt: string) {
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) {
    return `Ahoj ${name}, uvoľnil sa nám termín na ${serviceName} ${scheduledAt}. Chceš ho využiť?`;
  }

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      max_tokens: 140,
      messages: [{
        role: "user",
        content: `Napíš krátku prirodzenú slovenskú SMS pre klienta salónu. Oslov ho menom ${name}. Ponúkni uvoľnený termín ${scheduledAt} na službu ${serviceName}. Bez emoji, bez podpisu, max 240 znakov.`,
      }],
    }),
  });
  if (!response.ok) throw new Error(`OpenAI request failed: ${response.status}`);
  const data = await response.json();
  return data.choices?.[0]?.message?.content?.trim() ??
    `Ahoj ${name}, uvoľnil sa nám termín na ${serviceName} ${scheduledAt}. Chceš ho využiť?`;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return json({ ok: true });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    const body = await request.json() as SlotFillerRequest;
    if (!body.providerId) return json({ error: "providerId_required" }, 400);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const limit = Math.min(Math.max(body.candidateLimit ?? 12, 1), 50);
    const { data: candidates, error } = await supabase
      .from("client_profile_ai")
      .select("id,profile_id,preferred_barber,profiles(id,full_name,phone,email)")
      .eq("provider_id", body.providerId)
      .order("is_risk_of_loss", { ascending: false })
      .limit(limit);
    if (error) throw error;

    const scheduledAt = body.cancelledBooking?.scheduledAt ?? "dnes o 15:00";
    const serviceName = body.cancelledBooking?.serviceName ?? "strih";
    const batch = [];
    for (const candidate of candidates ?? []) {
      const profile = Array.isArray(candidate.profiles) ? candidate.profiles[0] : candidate.profiles;
      const name = profile?.full_name ?? "Klient";
      batch.push({
        clientProfileAiId: candidate.id,
        profileId: candidate.profile_id,
        name,
        phone: profile?.phone ?? null,
        email: profile?.email ?? null,
        draft: await draftMessage(name, serviceName, scheduledAt),
      });
    }

    return json({
      source: "SLOT_FILLER",
      providerId: body.providerId,
      cancelledSlot: body.cancelledBooking ?? null,
      count: batch.length,
      batch,
      generatedAt: new Date().toISOString(),
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "slot_filler_failed" }, 500);
  }
});