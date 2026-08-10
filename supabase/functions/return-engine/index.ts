import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return json({ ok: true });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    const { providerId } = await request.json() as { providerId?: string };
    if (!providerId) return json({ error: "providerId_required" }, 400);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const staleSince = new Date(Date.now() - 28 * 24 * 60 * 60 * 1000).toISOString();
    const { data: clients, error: clientError } = await supabase
      .from("client_profile_ai")
      .select("id,profile_id,last_visit_at,preferred_barber,is_risk_of_loss,profiles(id,full_name,phone,email)")
      .eq("provider_id", providerId)
      .or(`last_visit_at.lt.${staleSince},last_visit_at.is.null`)
      .order("is_risk_of_loss", { ascending: false })
      .limit(100);
    if (clientError) throw clientError;

    const notifications = (clients ?? []).map((client) => {
      const profile = Array.isArray(client.profiles) ? client.profiles[0] : client.profiles;
      return {
        user_id: client.profile_id,
        channel: "SMS",
        template: "RETURN_ENGINE",
        status: "PENDING",
        payload: {
          providerId,
          clientProfileAiId: client.id,
          name: profile?.full_name ?? "Klient",
          phone: profile?.phone ?? null,
          email: profile?.email ?? null,
          preferredBarber: client.preferred_barber,
          lastVisitAt: client.last_visit_at,
          draft: `Ahoj ${profile?.full_name ?? ""}, radi by sme ťa opäť privítali v salóne. Máš chuť rezervovať si svoj ďalší termín?`,
        },
      };
    });

    if (notifications.length > 0) {
      const { error: insertError } = await supabase.from("notifications").insert(notifications);
      if (insertError) throw insertError;
    }

    return json({
      source: "RETURN_ENGINE",
      providerId,
      count: notifications.length,
      notifications,
      generatedAt: new Date().toISOString(),
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "return_engine_failed" }, 500);
  }
});