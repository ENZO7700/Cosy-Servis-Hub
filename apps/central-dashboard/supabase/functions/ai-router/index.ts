// AI Router edge function — routes chat requests to Mistral, OpenAI or AnythingLLM
// with shared tool-calling (MCP-style) over the Triage bug database.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type Role = "system" | "user" | "assistant" | "tool";
type JsonRecord = Record<string, unknown>;
type ToolArgs = Partial<{
  status: string;
  severity: string;
  limit: number;
  tracking_id: string;
  query: string;
  bug_id: string;
}>;
type ToolCall = {
  id: string;
  function?: {
    name?: string;
    arguments?: string;
  };
};
type ProviderOutput = {
  content: string;
  tokens_in?: number;
  tokens_out?: number;
};

interface ChatMessage {
  role: Role;
  content: string;
  tool_call_id?: string;
  tool_calls?: ToolCall[];
  name?: string;
}
type Provider = "mistral" | "openai" | "anythingllm";

interface Body {
  providers: Provider[];
  model?: Partial<Record<Provider, string>>;
  messages: ChatMessage[];
  conversation_id: string;
  anythingllm?: { base_url?: string; workspace_slug?: string };
}

// ---------- Tool definitions (OpenAI / Mistral compatible) ----------
const tools = [
  {
    type: "function",
    function: {
      name: "list_bugs",
      description: "List bugs from the Triage database with optional filters.",
      parameters: {
        type: "object",
        properties: {
          status: { type: "string", enum: ["new", "in_progress", "resolved", "closed"] },
          severity: { type: "string", enum: ["low", "medium", "high", "critical"] },
          limit: { type: "integer", minimum: 1, maximum: 50, default: 10 },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_bug",
      description: "Fetch a single bug by tracking_id (e.g. BUG-00012).",
      parameters: {
        type: "object",
        properties: { tracking_id: { type: "string" } },
        required: ["tracking_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "search_comments",
      description: "Search comments by text. Optionally filter by bug_id.",
      parameters: {
        type: "object",
        properties: {
          query: { type: "string" },
          bug_id: { type: "string" },
        },
        required: ["query"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "count_bugs_by_status",
      description: "Return counts of bugs grouped by status.",
      parameters: { type: "object", properties: {} },
    },
  },
];

// ---------- Tool execution ----------
async function runTool(name: string, args: ToolArgs, supabase: ReturnType<typeof createClient>) {
  try {
    if (name === "list_bugs") {
      let q = supabase.from("bugs").select("tracking_id,title,status,severity,created_at").order("created_at", { ascending: false }).limit(args.limit ?? 10);
      if (args.status) q = q.eq("status", args.status);
      if (args.severity) q = q.eq("severity", args.severity);
      const { data, error } = await q;
      if (error) throw error;
      return { bugs: data };
    }
    if (name === "get_bug") {
      const { data, error } = await supabase.from("bugs").select("*").eq("tracking_id", args.tracking_id).maybeSingle();
      if (error) throw error;
      return data ?? { error: "not_found" };
    }
    if (name === "search_comments") {
      let q = supabase.from("comments").select("id,bug_id,content,created_at").ilike("content", `%${args.query}%`).limit(20);
      if (args.bug_id) q = q.eq("bug_id", args.bug_id);
      const { data, error } = await q;
      if (error) throw error;
      return { comments: data };
    }
    if (name === "count_bugs_by_status") {
      const { data, error } = await supabase.from("bugs").select("status");
      if (error) throw error;
      const counts: Record<string, number> = {};
      for (const row of data ?? []) counts[row.status] = (counts[row.status] ?? 0) + 1;
      return counts;
    }
    return { error: `unknown_tool:${name}` };
  } catch (e: unknown) {
    return { error: getErrorMessage(e, "tool_error") };
  }
}

// ---------- Provider callers ----------
async function callOpenAIish(url: string, apiKey: string, model: string, messages: ChatMessage[], supabase: ReturnType<typeof createClient>): Promise<ProviderOutput> {
  const convo = [...messages];
  for (let step = 0; step < 5; step++) {
    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({ model, messages: convo, tools, tool_choice: "auto" }),
    });
    const data = asRecord(await resp.json());
    if (!resp.ok) throw new Error(`[${resp.status}] ${JSON.stringify(data).slice(0, 400)}`);
    const msg = getAssistantMessage(data);
    convo.push(msg);
    if (msg.tool_calls?.length) {
      for (const tc of msg.tool_calls) {
        const toolName = tc.function?.name ?? "";
        const args = parseToolArgs(tc.function?.arguments);
        const result = await runTool(toolName, args, supabase);
        convo.push({ role: "tool", tool_call_id: tc.id, name: toolName, content: JSON.stringify(result) });
      }
      continue;
    }
    const usage = asRecord(data.usage);
    return {
      content: msg.content ?? "",
      tokens_in: getNumber(usage.prompt_tokens),
      tokens_out: getNumber(usage.completion_tokens),
    };
  }
  return { content: "(tool loop exceeded)", tokens_in: 0, tokens_out: 0 };
}

async function callMistral(model: string, messages: ChatMessage[], supabase: ReturnType<typeof createClient>) {
  const key = Deno.env.get("MISTRAL_API_KEY");
  if (!key) throw new Error("MISTRAL_API_KEY not configured");
  return callOpenAIish("https://api.mistral.ai/v1/chat/completions", key, model, messages, supabase);
}

async function callOpenAI(model: string, messages: ChatMessage[], supabase: ReturnType<typeof createClient>) {
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) throw new Error("OPENAI_API_KEY not configured");
  return callOpenAIish("https://api.openai.com/v1/chat/completions", key, model, messages, supabase);
}

async function callAnythingLLM(baseUrl: string | undefined, workspace: string | undefined, messages: ChatMessage[]) {
  const url = baseUrl ?? Deno.env.get("ANYTHINGLLM_BASE_URL");
  const ws = workspace ?? Deno.env.get("ANYTHINGLLM_WORKSPACE_SLUG");
  const key = Deno.env.get("ANYTHINGLLM_API_KEY");
  if (!url || !ws || !key) throw new Error("AnythingLLM not configured (need base_url, workspace_slug and ANYTHINGLLM_API_KEY)");
  const lastUser = [...messages].reverse().find(m => m.role === "user");
  const resp = await fetch(`${url.replace(/\/+$/, "")}/api/v1/workspace/${ws}/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({ message: lastUser?.content ?? "", mode: "chat" }),
  });
  const data = asRecord(await resp.json());
  if (!resp.ok) throw new Error(`[${resp.status}] ${JSON.stringify(data).slice(0, 400)}`);
  const content = getString(data.textResponse) ?? getString(data.response) ?? JSON.stringify(data);
  return { content, tokens_in: 0, tokens_out: 0 };
}

// ---------- Simple in-memory rate limit ----------
const buckets = new Map<string, { count: number; reset: number }>();
function checkRate(userId: string) {
  const now = Date.now();
  const b = buckets.get(userId);
  if (!b || b.reset < now) {
    buckets.set(userId, { count: 1, reset: now + 60_000 });
    return true;
  }
  if (b.count >= 30) return false;
  b.count++;
  return true;
}

// ---------- Handler ----------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "missing_auth" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Auth client (to validate user)
    const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: userErr } = await userClient.auth.getUser();
    if (userErr || !user) return json({ error: "unauthorized" }, 401);

    if (!checkRate(user.id)) return json({ error: "rate_limited" }, 429);

    const rawBody = asRecord(await req.json());

    // ---------- Test connection action ----------
    if (rawBody.action === "test_anythingllm") {
      const baseUrl = String(rawBody.base_url ?? "");
      const slug = String(rawBody.workspace_slug ?? "");
      if (!/^https:\/\/.+/.test(baseUrl)) return json({ ok: false, error: "base_url must be an https:// URL" });
      if (!slug || slug.length > 100) return json({ ok: false, error: "workspace_slug required (max 100 chars)" });
      const key = Deno.env.get("ANYTHINGLLM_API_KEY");
      if (!key) return json({ ok: false, reason: "missing_api_key", error: "ANYTHINGLLM_API_KEY secret not configured" });
      const ctrl = new AbortController();
      const t = setTimeout(() => ctrl.abort(), 10_000);
      const start = Date.now();
      try {
        const r = await fetch(`${baseUrl.replace(/\/+$/, "")}/api/v1/workspaces`, {
          headers: { Authorization: `Bearer ${key}`, Accept: "application/json" },
          signal: ctrl.signal,
        });
        const latency = Date.now() - start;
        const text = await r.text();
        if (!r.ok) return json({ ok: false, status: r.status, latency_ms: latency, error: text.slice(0, 300) });
        let parsed: unknown = null;
        try { parsed = JSON.parse(text); } catch { /* ignore */ }
        const parsedRecord = asRecord(parsed);
        const list = Array.isArray(parsedRecord.workspaces) ? parsedRecord.workspaces : Array.isArray(parsed) ? parsed : [];
        const found = list.some((w) => asRecord(w).slug === slug);
        return json({ ok: true, status: r.status, latency_ms: latency, workspace_found: found });
      } catch (e: unknown) {
        return json({ ok: false, latency_ms: Date.now() - start, error: isAbortError(e) ? "timeout after 10s" : getErrorMessage(e, "fetch_failed") });
      } finally {
        clearTimeout(t);
      }
    }

    // Tool client uses user JWT so RLS still applies (bugs/comments are readable by all authenticated)
    const toolClient = userClient;
    // Server client for writing ai_messages bypassing RLS verification overhead
    const adminClient = createClient(supabaseUrl, serviceKey);

    const body = rawBody as Body;

    if (!Array.isArray(body.providers) || body.providers.length === 0) return json({ error: "providers_required" }, 400);
    if (!Array.isArray(body.messages) || body.messages.length === 0) return json({ error: "messages_required" }, 400);
    if (!body.conversation_id) return json({ error: "conversation_id_required" }, 400);
    for (const m of body.messages) {
      if (typeof m.content === "string" && m.content.length > 8000) return json({ error: "message_too_long" }, 400);
    }

    const systemPrompt: ChatMessage = {
      role: "system",
      content:
        "You are the Triage AI assistant for a bug tracker. Use the available tools to look up bugs, comments and statistics in the database. Be concise and answer in the user's language.",
    };
    const messagesWithSystem = [systemPrompt, ...body.messages.filter(m => m.role !== "system")];

    const defaults: Record<Provider, string> = {
      mistral: "mistral-large-latest",
      openai: "gpt-4o-mini",
      anythingllm: "workspace",
    };

    const results = await Promise.all(
      body.providers.map(async (provider) => {
        const start = Date.now();
        const model = body.model?.[provider] ?? defaults[provider];
        try {
          let out: ProviderOutput;
          if (provider === "mistral") out = await callMistral(model, messagesWithSystem, toolClient);
          else if (provider === "openai") out = await callOpenAI(model, messagesWithSystem, toolClient);
          else out = await callAnythingLLM(body.anythingllm?.base_url, body.anythingllm?.workspace_slug, messagesWithSystem);

          const latency = Date.now() - start;
          await adminClient.from("ai_messages").insert({
            conversation_id: body.conversation_id,
            user_id: user.id,
            role: "assistant",
            content: out.content,
            provider,
            model,
            tokens_in: out.tokens_in ?? null,
            tokens_out: out.tokens_out ?? null,
            latency_ms: latency,
          });
          return { provider, model, content: out.content, latency_ms: latency, tokens_in: out.tokens_in, tokens_out: out.tokens_out };
        } catch (e: unknown) {
          const latency = Date.now() - start;
          const errMsg = getErrorMessage(e, "unknown_error");
          await adminClient.from("ai_messages").insert({
            conversation_id: body.conversation_id,
            user_id: user.id,
            role: "assistant",
            content: "",
            provider,
            model,
            latency_ms: latency,
            error: errMsg,
          });
          return { provider, model, error: errMsg, latency_ms: latency };
        }
      })
    );

    // Bump conversation updated_at
    await adminClient.from("ai_conversations").update({ updated_at: new Date().toISOString() }).eq("id", body.conversation_id);

    return json({ results });
  } catch (e: unknown) {
    console.error("ai-router error", e);
    return json({ error: getErrorMessage(e, "internal_error") }, 500);
  }
});

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function asRecord(value: unknown): JsonRecord {
  return typeof value === "object" && value !== null ? value as JsonRecord : {};
}

function getString(value: unknown) {
  return typeof value === "string" ? value : undefined;
}

function getNumber(value: unknown) {
  return typeof value === "number" ? value : undefined;
}

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

function isAbortError(error: unknown) {
  return error instanceof Error && error.name === "AbortError";
}

function parseToolArgs(value: string | undefined): ToolArgs {
  if (!value) return {};

  try {
    return asRecord(JSON.parse(value));
  } catch {
    return {};
  }
}

function getAssistantMessage(data: JsonRecord): ChatMessage {
  const choices = Array.isArray(data.choices) ? data.choices : [];
  const choice = asRecord(choices[0]);
  const message = asRecord(choice.message);
  const toolCalls = Array.isArray(message.tool_calls) ? message.tool_calls.map(toToolCall).filter(Boolean) : undefined;
  const content = getString(message.content);

  if (!content && !toolCalls?.length) throw new Error("no_message");

  return {
    role: "assistant",
    content: content ?? "",
    tool_calls: toolCalls,
  };
}

function toToolCall(value: unknown): ToolCall | undefined {
  const record = asRecord(value);
  const id = getString(record.id);
  const fn = asRecord(record.function);
  const name = getString(fn.name);

  if (!id || !name) return undefined;

  return {
    id,
    function: {
      name,
      arguments: getString(fn.arguments),
    },
  };
}
