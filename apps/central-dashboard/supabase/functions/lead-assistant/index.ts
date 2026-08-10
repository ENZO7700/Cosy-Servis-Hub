import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { createRemoteJWKSet, jwtVerify, SignJWT } from "npm:jose@6.1.0";

type Json = Record<string, unknown>;
type FirebaseIdentity = { uid: string; email?: string };

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const ALLOWED_ORIGINS = (Deno.env.get("CRM_ALLOWED_ORIGIN") ?? "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);
const MISTRAL_API_KEY = Deno.env.get("MISTRAL_API_KEY") ?? "";
const GMAIL_CLIENT_ID = Deno.env.get("GMAIL_CLIENT_ID") ?? "";
const GMAIL_CLIENT_SECRET = Deno.env.get("GMAIL_CLIENT_SECRET") ?? "";
const GMAIL_REDIRECT_URI = Deno.env.get("GMAIL_REDIRECT_URI") ?? "";
const CRM_APP_URL = Deno.env.get("CRM_APP_URL") ?? "";
const OAUTH_STATE_SECRET = Deno.env.get("OAUTH_STATE_SECRET") ?? "";
const TOKEN_ENCRYPTION_KEY = Deno.env.get("TOKEN_ENCRYPTION_KEY") ?? "";

const firebaseJwks = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

const rateBuckets = new Map<string, { startedAt: number; count: number }>();

Deno.serve(async (request) => {
  const cors = corsHeaders(request);
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    enforceOrigin(request);

    const url = new URL(request.url);
    if (request.method === "GET" && url.searchParams.has("code")) {
      return await handleOAuthCallback(url);
    }
    if (request.method !== "POST") {
      return response({ error: "method_not_allowed" }, 405, cors);
    }

    const identity = await verifyFirebaseRequest(request);
    if (!checkRate(identity.uid)) {
      return response({ error: "rate_limited" }, 429, cors);
    }

    const body = asRecord(await request.json());
    const action = stringValue(body.action);

    switch (action) {
      case "parse_leads":
        return response(await parseLeads(body), 200, cors);
      case "parse_leads_chunk":
        return response(await parseLeadsChunk(body), 200, cors);
      case "generate_outreach":
        return response(await generateOutreach(body), 200, cors);
      case "generate_offer":
        return response(await generateOffer(body), 200, cors);
      case "gmail_status":
        return response(await gmailStatus(identity), 200, cors);
      case "gmail_connect_url":
        return response(await gmailConnectUrl(identity), 200, cors);
      case "gmail_disconnect":
        return response(await gmailDisconnect(identity), 200, cors);
      case "send_email":
        return response(await sendEmail(identity, body), 200, cors);
      default:
        return response({ error: "invalid_action" }, 400, cors);
    }
  } catch (error) {
    const known = error instanceof ApiError ? error : null;
    if (!known) console.error("lead-assistant failed", safeErrorCode(error));
    return response(
      { error: known?.code ?? "internal_error" },
      known?.status ?? 500,
      cors,
    );
  }
});

const PARSE_SYSTEM_PROMPT =
  `You extract sales leads from Slovak/English daily reports.
Return JSON only as {"leads":[...]}. Never invent contact details, prices, sources,
or facts. Empty/ambiguous values must be empty strings and their field names must
appear in uncertain_fields. Ignore summaries and statistics. Merge continuation
fragments only when they clearly belong to the same lead.

Each lead must contain exactly:
id (empty string), company_name, website, location, company_size, sector,
contact_name, contact_role, email, phone, linkedin, score (0-10 number),
partial_scores (object with integer values when present), problem,
decision_maker, trigger, revenue_estimate, sources (string array),
uncertain_fields (string array), raw_text (the source block for this lead).
Do not treat phrases such as "cez web", "via LinkedIn", or a bare domain as an email.`;

function parseLeadMessages(chunk: string, chunkIndex: number, chunkTotal: number) {
  const meta = chunkTotal > 0
    ? `\n\n[chunk ${chunkIndex + 1}/${chunkTotal}]`
    : "";
  return [
    { role: "system", content: PARSE_SYSTEM_PROMPT },
    { role: "user", content: `${chunk}${meta}` },
  ];
}

async function parseLeadsChunk(body: Json) {
  const rawText = stringValue(body.raw_text).trim();
  if (rawText.length < 20 || rawText.length > 8_000) {
    throw new ApiError("invalid_input", 400);
  }
  const chunkIndex = Math.max(0, Math.floor(numberValue(body.chunk_index)));
  const chunkTotal = Math.max(0, Math.floor(numberValue(body.chunk_total)));
  const started = Date.now();
  const result = await callMistral(
    parseLeadMessages(rawText, chunkIndex, chunkTotal),
    { maxTokens: 3_000, parseLadder: true },
  );
  if (!Array.isArray(result.leads)) {
    throw new ApiError("invalid_ai_response", 502);
  }
  const leads = tryValidateLeads(result.leads);
  console.log(
    JSON.stringify({
      event: "parse_leads_chunk",
      job_id: stringValue(body.job_id).slice(0, 64),
      chunk_index: chunkIndex,
      chunk_total: chunkTotal,
      input_chars: rawText.length,
      leads: leads.length,
      latency_ms: Date.now() - started,
    }),
  );
  return { leads, chunk_index: chunkIndex };
}

async function parseLeads(body: Json) {
  const rawText = stringValue(body.raw_text).trim();
  if (rawText.length < 40 || rawText.length > 120_000) {
    throw new ApiError("invalid_input", 400);
  }
  const chunks = splitLeadReport(rawText);
  const extracted: Json[] = [];
  const failedChunks: Array<
    { index: number; reason: string; preview: string }
  > = [];

  for (let index = 0; index < chunks.length; index++) {
    const chunk = chunks[index];
    try {
      const result = await callMistral(
        parseLeadMessages(chunk, index, chunks.length),
        { maxTokens: 3_000, parseLadder: true },
      );
      if (!Array.isArray(result.leads)) {
        throw new ApiError("invalid_ai_response", 502);
      }
      extracted.push(...tryValidateLeads(result.leads));
    } catch (error) {
      const reason = error instanceof ApiError
        ? error.code
        : "mistral_unavailable";
      failedChunks.push({
        index,
        reason,
        preview: chunk.slice(0, 120),
      });
    }
  }

  if (extracted.length === 0) {
    throw new ApiError(
      failedChunks.length > 0 ? "mistral_unavailable" : "invalid_ai_response",
      502,
    );
  }
  if (extracted.length > 500) {
    throw new ApiError("invalid_ai_response", 502);
  }

  return {
    leads: extracted,
    stats: {
      chunks_total: chunks.length,
      chunks_ok: chunks.length - failedChunks.length,
      chunks_failed: failedChunks.length,
      leads_found: extracted.length,
    },
    failed_chunks: failedChunks,
  };
}

async function generateOutreach(body: Json) {
  const lead = sanitizeLead(asRecord(body.lead));
  const result = await callMistral(
    [
      {
        role: "system",
        content:
          `Create concise, human sales outreach using only supplied facts.
Return JSON only as {"outreach":{subject_sk,email_sk,subject_en,email_en,
linkedin_message,follow_up_day_5}}. Both emails need a clear 15-minute CTA.
Do not invent proof, integrations, customers, prices, or contact details.
LinkedIn and follow-up are English unless the lead is clearly Slovak.`,
      },
      { role: "user", content: JSON.stringify(lead) },
    ],
    { maxTokens: 3_000, model: "mistral-large-latest" },
  );
  const outreach = asRecord(result.outreach);
  const required = [
    "subject_sk",
    "email_sk",
    "subject_en",
    "email_en",
    "linkedin_message",
    "follow_up_day_5",
  ];
  for (const field of required) {
    if (!stringValue(outreach[field]).trim()) {
      throw new ApiError("invalid_ai_response", 502);
    }
  }
  return { outreach };
}

async function generateOffer(body: Json) {
  const lead = sanitizeLead(asRecord(body.lead));
  const result = await callMistral(
    [
      {
        role: "system",
        content:
          `Prepare an internal, non-binding sales solution outline in Slovak.
Return JSON only as {"offer":{recommended_solution,problem_and_benefit,
core_features,mvp_scope,optional_extensions,price_range,duration,next_step}}.
The three feature fields are arrays of concise strings. Price must be an
explicitly labelled indicative range based on scope, never a factual claim
about the lead. Use only supplied lead facts.`,
      },
      { role: "user", content: JSON.stringify(lead) },
    ],
    { maxTokens: 3_000, model: "mistral-large-latest" },
  );
  const offer = asRecord(result.offer);
  for (
    const field of [
      "recommended_solution",
      "problem_and_benefit",
      "price_range",
      "duration",
      "next_step",
    ]
  ) {
    if (!stringValue(offer[field]).trim()) {
      throw new ApiError("invalid_ai_response", 502);
    }
  }
  for (
    const field of ["core_features", "mvp_scope", "optional_extensions"]
  ) {
    if (!Array.isArray(offer[field])) {
      throw new ApiError("invalid_ai_response", 502);
    }
  }
  return { offer };
}

type MistralCallOptions = {
  maxTokens: number;
  model?: string;
  timeoutMs?: number;
  parseLadder?: boolean;
};

async function callMistral(
  messages: Array<{ role: string; content: string }>,
  options: MistralCallOptions,
): Promise<Json> {
  if (!MISTRAL_API_KEY) throw new ApiError("mistral_unavailable", 503);

  const attempts = options.parseLadder
    ? [
      { model: "mistral-small-latest", timeoutMs: 30_000 },
      { model: "mistral-small-latest", timeoutMs: 30_000 },
      { model: "mistral-large-latest", timeoutMs: 45_000 },
    ]
    : [
      {
        model: options.model ?? "mistral-large-latest",
        timeoutMs: options.timeoutMs ?? 45_000,
      },
      {
        model: options.model ?? "mistral-large-latest",
        timeoutMs: options.timeoutMs ?? 45_000,
      },
    ];

  let lastError: ApiError | null = null;
  for (let i = 0; i < attempts.length; i++) {
    const attempt = attempts[i];
    try {
      return await callMistralOnce(
        messages,
        options.maxTokens,
        attempt.model,
        attempt.timeoutMs,
      );
    } catch (error) {
      const apiErr = error instanceof ApiError
        ? error
        : new ApiError("mistral_unavailable", 502);
      lastError = apiErr;
      const retryable = [
        "rate_limited",
        "mistral_unavailable",
        "mistral_timeout",
        "invalid_ai_response",
      ].includes(apiErr.code);
      if (!retryable || i === attempts.length - 1) throw apiErr;
      await sleep(400 * (i + 1) + Math.floor(Math.random() * 400));
    }
  }
  throw lastError ?? new ApiError("mistral_unavailable", 502);
}

async function callMistralOnce(
  messages: Array<{ role: string; content: string }>,
  maxTokens: number,
  model: string,
  timeoutMs: number,
): Promise<Json> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const apiResponse = await fetch(
      "https://api.mistral.ai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${MISTRAL_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          messages,
          temperature: 0.1,
          max_tokens: maxTokens,
          response_format: { type: "json_object" },
        }),
        signal: controller.signal,
      },
    );
    if (apiResponse.status === 429) {
      throw new ApiError("rate_limited", 429);
    }
    if (!apiResponse.ok) {
      throw new ApiError("mistral_unavailable", 502);
    }
    const payload = asRecord(await apiResponse.json());
    const choices = payload.choices;
    if (!Array.isArray(choices) || choices.length === 0) {
      throw new ApiError("invalid_ai_response", 502);
    }
    const message = asRecord(asRecord(choices[0]).message);
    return parseJsonObject(stringValue(message.content));
  } catch (error) {
    if (error instanceof ApiError) throw error;
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new ApiError("mistral_timeout", 504);
    }
    if (error instanceof Error && error.name === "AbortError") {
      throw new ApiError("mistral_timeout", 504);
    }
    throw new ApiError("mistral_unavailable", 502);
  } finally {
    clearTimeout(timeout);
  }
}

function parseJsonObject(content: string): Json {
  let text = content.trim();
  text = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
  try {
    return asRecord(JSON.parse(text));
  } catch {
    const last = text.lastIndexOf("}");
    if (last > 0) {
      try {
        return asRecord(JSON.parse(text.slice(0, last + 1)));
      } catch {
        // fall through
      }
    }
    throw new ApiError("invalid_ai_response", 502);
  }
}

function tryValidateLeads(items: unknown[]): Json[] {
  const leads: Json[] = [];
  for (const item of items) {
    try {
      leads.push(validateLead(item));
    } catch {
      // skip malformed lead objects from a partial JSON payload
    }
  }
  return leads;
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function gmailStatus(identity: FirebaseIdentity) {
  const { data, error } = await adminClient()
    .from("cmr_gmail_outreach_integrations")
    .select("gmail_address")
    .eq("firebase_uid", identity.uid)
    .maybeSingle();
  if (error) throw new ApiError("storage_error", 500);
  return {
    connected: Boolean(data),
    email: data?.gmail_address ?? "",
  };
}

async function gmailConnectUrl(identity: FirebaseIdentity) {
  requireGmailConfig();
  const state = await new SignJWT({ uid: identity.uid })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("10m")
    .setAudience("gmail-oauth")
    .setIssuer("cmr-plus")
    .sign(new TextEncoder().encode(OAUTH_STATE_SECRET));
  const params = new URLSearchParams({
    client_id: GMAIL_CLIENT_ID,
    redirect_uri: GMAIL_REDIRECT_URI,
    response_type: "code",
    scope: "openid email https://www.googleapis.com/auth/gmail.send",
    access_type: "offline",
    prompt: "consent",
    include_granted_scopes: "true",
    state,
  });
  return {
    url: `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`,
  };
}

async function handleOAuthCallback(url: URL) {
  requireGmailConfig();
  const code = url.searchParams.get("code") ?? "";
  const state = url.searchParams.get("state") ?? "";
  if (!code || !state) throw new ApiError("invalid_oauth_callback", 400);
  const verified = await jwtVerify(
    state,
    new TextEncoder().encode(OAUTH_STATE_SECRET),
    {
      algorithms: ["HS256"],
      audience: "gmail-oauth",
      issuer: "cmr-plus",
    },
  );
  const uid = stringValue(verified.payload.uid);
  if (!uid) throw new ApiError("invalid_oauth_callback", 400);

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: GMAIL_CLIENT_ID,
      client_secret: GMAIL_CLIENT_SECRET,
      redirect_uri: GMAIL_REDIRECT_URI,
      grant_type: "authorization_code",
    }),
  });
  const tokens = asRecord(await tokenResponse.json());
  const refreshToken = stringValue(tokens.refresh_token);
  const accessToken = stringValue(tokens.access_token);
  if (!tokenResponse.ok || !refreshToken || !accessToken) {
    throw new ApiError("gmail_oauth_failed", 400);
  }
  const profile = await fetch(
    "https://gmail.googleapis.com/gmail/v1/users/me/profile",
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  const profileData = asRecord(await profile.json());
  const gmailAddress = stringValue(profileData.emailAddress);
  if (!profile.ok || !validEmail(gmailAddress)) {
    throw new ApiError("gmail_oauth_failed", 400);
  }
  const encrypted = await encryptToken(refreshToken);
  const { error } = await adminClient()
    .from("cmr_gmail_outreach_integrations")
    .upsert({
      firebase_uid: uid,
      gmail_address: gmailAddress,
      encrypted_refresh_token: encrypted.ciphertext,
      token_iv: encrypted.iv,
      updated_at: new Date().toISOString(),
    }, { onConflict: "firebase_uid" });
  if (error) throw new ApiError("storage_error", 500);
  return Response.redirect(`${CRM_APP_URL}?gmail=connected`, 302);
}

async function gmailDisconnect(identity: FirebaseIdentity) {
  const admin = adminClient();
  const { data } = await admin
    .from("cmr_gmail_outreach_integrations")
    .select("encrypted_refresh_token,token_iv")
    .eq("firebase_uid", identity.uid)
    .maybeSingle();
  if (data) {
    try {
      const refreshToken = await decryptToken(
        data.encrypted_refresh_token,
        data.token_iv,
      );
      await fetch(
        `https://oauth2.googleapis.com/revoke?token=${
          encodeURIComponent(refreshToken)
        }`,
        {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
        },
      );
    } catch {
      // Local deletion still revokes the app's access path.
    }
  }
  const { error } = await admin
    .from("cmr_gmail_outreach_integrations")
    .delete()
    .eq("firebase_uid", identity.uid);
  if (error) throw new ApiError("storage_error", 500);
  return { disconnected: true };
}

async function sendEmail(identity: FirebaseIdentity, body: Json) {
  requireGmailConfig();
  const to = stringValue(body.to).trim().toLowerCase();
  const subject = stringValue(body.subject).trim();
  const messageBody = stringValue(body.body).trim();
  const leadId = stringValue(body.lead_id).trim();
  const idempotencyKey = stringValue(body.idempotency_key).trim();
  if (
    !validEmail(to) || subject.length < 1 || subject.length > 200 ||
    messageBody.length < 1 || messageBody.length > 12_000 ||
    leadId.length < 1 || leadId.length > 200 ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(idempotencyKey)
  ) {
    throw new ApiError("invalid_recipient", 400);
  }

  const admin = adminClient();
  const recipientHash = await sha256(to);
  const insert = await admin.from("cmr_gmail_outreach_sends").insert({
    firebase_uid: identity.uid,
    idempotency_key: idempotencyKey,
    lead_id: leadId,
    recipient_hash: recipientHash,
    status: "processing",
  }).select("id").single();
  if (insert.error?.code === "23505") {
    const existing = await admin
      .from("cmr_gmail_outreach_sends")
      .select("status,gmail_message_id")
      .eq("firebase_uid", identity.uid)
      .eq("idempotency_key", idempotencyKey)
      .maybeSingle();
    if (existing.data?.status === "sent") {
      return { sent: true, duplicate: true };
    }
    throw new ApiError("duplicate_send", 409);
  }
  if (insert.error || !insert.data) throw new ApiError("storage_error", 500);

  try {
    const integration = await admin
      .from("cmr_gmail_outreach_integrations")
      .select("gmail_address,encrypted_refresh_token,token_iv")
      .eq("firebase_uid", identity.uid)
      .maybeSingle();
    if (integration.error || !integration.data) {
      throw new ApiError("gmail_not_connected", 409);
    }
    const refreshToken = await decryptToken(
      integration.data.encrypted_refresh_token,
      integration.data.token_iv,
    );
    const accessToken = await refreshGmailAccessToken(refreshToken);
    const mime = [
      `From: ${integration.data.gmail_address}`,
      `To: ${to}`,
      `Subject: ${encodeMimeHeader(subject)}`,
      "MIME-Version: 1.0",
      'Content-Type: text/plain; charset="UTF-8"',
      "Content-Transfer-Encoding: 8bit",
      "",
      messageBody,
    ].join("\r\n");
    const gmailResponse = await fetch(
      "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          raw: base64Url(new TextEncoder().encode(mime)),
        }),
      },
    );
    const gmailData = asRecord(await gmailResponse.json());
    if (!gmailResponse.ok || !stringValue(gmailData.id)) {
      throw new ApiError("gmail_send_failed", 502);
    }
    await admin.from("cmr_gmail_outreach_sends").update({
      status: "sent",
      gmail_message_id: stringValue(gmailData.id),
      updated_at: new Date().toISOString(),
    }).eq("id", insert.data.id);
    return { sent: true };
  } catch (error) {
    await admin.from("cmr_gmail_outreach_sends").update({
      status: "failed",
      error_code: error instanceof ApiError ? error.code : "gmail_send_failed",
      updated_at: new Date().toISOString(),
    }).eq("id", insert.data.id);
    throw error;
  }
}

async function verifyFirebaseRequest(
  request: Request,
): Promise<FirebaseIdentity> {
  if (!FIREBASE_PROJECT_ID) throw new ApiError("server_not_configured", 503);
  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    throw new ApiError("unauthorized", 401);
  }
  try {
    const { payload } = await jwtVerify(
      authorization.slice(7),
      firebaseJwks,
      {
        algorithms: ["RS256"],
        issuer: `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
        audience: FIREBASE_PROJECT_ID,
      },
    );
    const uid = stringValue(payload.sub);
    if (!uid) throw new Error("missing subject");
    return { uid, email: stringValue(payload.email) || undefined };
  } catch {
    throw new ApiError("unauthorized", 401);
  }
}

function adminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) throw new ApiError("server_not_configured", 503);
  return createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function requireGmailConfig() {
  if (
    !GMAIL_CLIENT_ID || !GMAIL_CLIENT_SECRET || !GMAIL_REDIRECT_URI ||
    !CRM_APP_URL || !OAUTH_STATE_SECRET || !TOKEN_ENCRYPTION_KEY
  ) {
    throw new ApiError("server_not_configured", 503);
  }
}

async function refreshGmailAccessToken(refreshToken: string) {
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: GMAIL_CLIENT_ID,
      client_secret: GMAIL_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });
  const data = asRecord(await tokenResponse.json());
  const accessToken = stringValue(data.access_token);
  if (!tokenResponse.ok || !accessToken) {
    throw new ApiError("gmail_not_connected", 409);
  }
  return accessToken;
}

async function encryptionKey() {
  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(
      atob(TOKEN_ENCRYPTION_KEY),
      (char) => char.charCodeAt(0),
    );
  } catch {
    throw new ApiError("server_not_configured", 503);
  }
  if (bytes.length !== 32) throw new ApiError("server_not_configured", 503);
  const keyBuffer = new ArrayBuffer(bytes.length);
  new Uint8Array(keyBuffer).set(bytes);
  return crypto.subtle.importKey("raw", keyBuffer, "AES-GCM", false, [
    "encrypt",
    "decrypt",
  ]);
}

async function encryptToken(token: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    await encryptionKey(),
    new TextEncoder().encode(token),
  );
  return {
    ciphertext: base64Url(new Uint8Array(ciphertext)),
    iv: base64Url(iv),
  };
}

async function decryptToken(ciphertext: string, iv: string) {
  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: fromBase64Url(iv) },
    await encryptionKey(),
    fromBase64Url(ciphertext),
  );
  return new TextDecoder().decode(decrypted);
}

function validateLead(value: unknown) {
  const lead = asRecord(value);
  if (!stringValue(lead.company_name).trim()) {
    throw new ApiError("invalid_ai_response", 502);
  }
  lead.score = Math.min(10, Math.max(0, numberValue(lead.score)));
  lead.sources = stringArray(lead.sources).slice(0, 30);
  lead.uncertain_fields = stringArray(lead.uncertain_fields).slice(0, 30);
  // Normalize partial_scores so clients never receive string/list hybrids.
  const rawPartial = asRecord(lead.partial_scores);
  const normalizedPartial: Json = {};
  for (const [key, value] of Object.entries(rawPartial)) {
    normalizedPartial[key] = Math.round(numberValue(value));
  }
  lead.partial_scores = normalizedPartial;
  for (
    const field of [
      "id",
      "company_name",
      "website",
      "location",
      "company_size",
      "sector",
      "contact_name",
      "contact_role",
      "email",
      "phone",
      "linkedin",
      "problem",
      "decision_maker",
      "trigger",
      "revenue_estimate",
      "raw_text",
    ]
  ) {
    lead[field] = stringValue(lead[field]).slice(
      0,
      field === "raw_text" ? 20_000 : 8_000,
    );
  }
  if (!validEmail(stringValue(lead.email))) {
    lead.email = "";
    if (!stringArray(lead.uncertain_fields).includes("email")) {
      lead.uncertain_fields = [...stringArray(lead.uncertain_fields), "email"];
    }
  }
  return lead;
}

function sanitizeLead(lead: Json) {
  const sanitized = { ...lead };
  delete sanitized.outreach;
  delete sanitized.offer;
  delete sanitized.raw_text;
  delete sanitized.sent_at;
  delete sanitized.follow_up_at;
  return sanitized;
}

function splitLeadReport(rawText: string) {
  const maxChunkLength = 5_000;
  const maxLeadsPerChunk = 3;
  const overlap = 400;

  if (rawText.length <= maxChunkLength) {
    const leadMarkers =
      (rawText.match(/^\s*(?:🔥)?\s*LEAD\s+\d+/gmi) ?? []).length;
    if (leadMarkers <= maxLeadsPerChunk) return [rawText];
  }

  let sections = rawText
    .split(/(?=^\s*(?:🔥)?\s*LEAD\s+\d+)/gmi)
    .filter((section) => section.trim());
  if (sections.length <= 1) {
    sections = rawText.split(/\n{2,}/).filter((section) => section.trim());
  }
  if (sections.length === 0) return [rawText];

  const chunks: string[] = [];
  let current = "";
  let leadCount = 0;

  const flush = () => {
    if (current.trim()) chunks.push(current.trim());
    current = "";
    leadCount = 0;
  };

  for (const section of sections) {
    const isLead = /^\s*(?:🔥)?\s*LEAD\s+\d+/im.test(section);
    if (section.length > maxChunkLength) {
      flush();
      for (
        let offset = 0;
        offset < section.length;
        offset += maxChunkLength - overlap
      ) {
        const end = Math.min(offset + maxChunkLength, section.length);
        const slice = section.slice(offset, end).trim();
        if (slice) chunks.push(slice);
        if (end >= section.length) break;
      }
      continue;
    }

    const nextLeadCount = leadCount + (isLead ? 1 : 0);
    if (
      current.trim() &&
      (current.length + section.length > maxChunkLength ||
        nextLeadCount > maxLeadsPerChunk)
    ) {
      flush();
    }
    current += section;
    leadCount += isLead ? 1 : 0;
  }
  flush();
  return chunks.length > 0 ? chunks : [rawText];
}

function enforceOrigin(request: Request) {
  const origin = request.headers.get("Origin");
  if (origin && ALLOWED_ORIGINS.length > 0 && !ALLOWED_ORIGINS.includes(origin)) {
    throw new ApiError("forbidden_origin", 403);
  }
}

function corsHeaders(request: Request) {
  const requestOrigin = request.headers.get("Origin") ?? "";
  const allowOrigin = ALLOWED_ORIGINS.includes(requestOrigin)
    ? requestOrigin
    : "null";
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
    "Vary": "Origin",
  };
}

function checkRate(uid: string) {
  const now = Date.now();
  const current = rateBuckets.get(uid);
  if (!current || now - current.startedAt >= 60_000) {
    rateBuckets.set(uid, { startedAt: now, count: 1 });
    return true;
  }
  if (current.count >= 60) return false;
  current.count++;
  return true;
}

function response(
  payload: unknown,
  status: number,
  headers: Record<string, string>,
) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}

function asRecord(value: unknown): Json {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Json
    : {};
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value : "";
}

function numberValue(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function stringArray(value: unknown) {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

function validEmail(value: string) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value) && value.length <= 254;
}

function base64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

function fromBase64Url(value: string) {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(
    normalized.length + ((4 - normalized.length % 4) % 4),
    "=",
  );
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
}

function encodeMimeHeader(value: string) {
  return `=?UTF-8?B?${btoa(unescape(encodeURIComponent(value)))}?=`;
}

async function sha256(value: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return base64Url(new Uint8Array(digest));
}

function safeErrorCode(error: unknown) {
  if (error instanceof Error) return error.name;
  return "unknown";
}

class ApiError extends Error {
  constructor(public code: string, public status: number) {
    super(code);
  }
}
