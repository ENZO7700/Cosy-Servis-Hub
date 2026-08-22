import assert from "node:assert/strict";
import {
  createHandler,
  type FetchLike,
  fetchSalonosStats,
  SalonosIntegrationError,
} from "../base44/functions/salonosDailyStats/reader.ts";

const providerId = "provider-001";
const config = {
  baseUrl: "https://servishub.example",
  providerId,
  apiToken: "test-token-123456789",
  attempts: 2,
  timeoutMs: 1_000,
};

function canonicalPayload(overrides: Record<string, unknown> = {}) {
  return {
    provider: {
      id: providerId,
      businessName: "Example Services",
      businessType: "HOME_SERVICES",
    },
    totalAiRevenue: 1_250,
    breakdown: {
      returnEngine: 500,
      slotFiller: 450,
      noShowGuards: 300,
    },
    dailyActions: [
      {
        id: "return-engine",
        title: "Contact clients ready to return",
        detail: "Aggregate SALONOS opportunity count.",
        count: 8,
      },
    ],
    currency: "EUR",
    periodStart: "2026-08-01T00:00:00.000Z",
    recentLogs: [{ description: "must not leave SALONOS" }],
    internalOnly: "must be dropped",
    ...overrides,
  };
}

function jsonResponse(payload: unknown, status = 200): Response {
  return Response.json(payload, { status });
}

const noSleep = () => Promise.resolve();

Deno.test("returns only the canonical aggregate contract", async () => {
  let observedMethod: string | undefined;
  let observedUrl = "";
  let observedAuthorization = "";
  const fetcher: FetchLike = async (input, init) => {
    observedUrl = String(input);
    observedMethod = init?.method;
    observedAuthorization = new Headers(init?.headers).get("authorization") ?? "";
    return jsonResponse(canonicalPayload());
  };

  const result = await fetchSalonosStats(config, { fetcher, sleep: noSleep });

  assert.equal(observedMethod, "GET");
  assert.equal(
    observedUrl,
    `https://servishub.example/api/v1/salonos/stats/${providerId}`,
  );
  assert.equal(observedAuthorization, `Bearer ${config.apiToken}`);
  assert.equal(result.provider.id, providerId);
  assert.equal(result.dailyActions[0].count, 8);
  assert.equal("recentLogs" in result, false);
  assert.equal("internalOnly" in result, false);
});

Deno.test("accepts the canonical empty state", async () => {
  const fetcher: FetchLike = () =>
    Promise.resolve(
      jsonResponse(
        canonicalPayload({
          totalAiRevenue: 0,
          breakdown: { returnEngine: 0, slotFiller: 0, noShowGuards: 0 },
          dailyActions: [],
        }),
      ),
    );

  const result = await fetchSalonosStats(config, { fetcher, sleep: noSleep });
  assert.equal(result.totalAiRevenue, 0);
  assert.deepEqual(result.dailyActions, []);
});

Deno.test("fails closed when SALONOS returns another provider", async () => {
  const fetcher: FetchLike = () =>
    Promise.resolve(
      jsonResponse(
        canonicalPayload({
          provider: {
            id: "provider-999",
            businessName: "Wrong tenant",
            businessType: "OTHER",
          },
        }),
      ),
    );

  await assert.rejects(
    () => fetchSalonosStats(config, { fetcher, sleep: noSleep }),
    (error: unknown) =>
      error instanceof SalonosIntegrationError &&
      error.code === "TENANT_MISMATCH",
  );
});

Deno.test("rejects an incompatible DTO", async () => {
  const fetcher: FetchLike = () =>
    Promise.resolve(
      jsonResponse(
        canonicalPayload({
          totalAiRevenue: 99,
        }),
      ),
    );

  await assert.rejects(
    () => fetchSalonosStats(config, { fetcher, sleep: noSleep }),
    (error: unknown) =>
      error instanceof SalonosIntegrationError &&
      error.code === "CONTRACT_INVALID",
  );
});

Deno.test("rejects duplicate daily action IDs", async () => {
  const action = {
    id: "return-engine",
    title: "Return",
    detail: "Aggregate count.",
    count: 1,
  };
  const fetcher: FetchLike = () =>
    Promise.resolve(
      jsonResponse(canonicalPayload({ dailyActions: [action, action] })),
    );

  await assert.rejects(
    () => fetchSalonosStats(config, { fetcher, sleep: noSleep }),
    (error: unknown) =>
      error instanceof SalonosIntegrationError &&
      error.code === "CONTRACT_INVALID",
  );
});

Deno.test("does not retry authentication or tenant authorization failures", async () => {
  for (const status of [401, 403]) {
    let attempts = 0;
    const fetcher: FetchLike = () => {
      attempts += 1;
      return Promise.resolve(jsonResponse({ error: "redacted" }, status));
    };

    await assert.rejects(
      () => fetchSalonosStats(config, { fetcher, sleep: noSleep }),
      (error: unknown) =>
        error instanceof SalonosIntegrationError &&
        error.code ===
          (status === 401 ? "UPSTREAM_UNAUTHORIZED" : "UPSTREAM_FORBIDDEN"),
    );
    assert.equal(attempts, 1);
  }
});

Deno.test("retries a transient upstream failure exactly once", async () => {
  let attempts = 0;
  let sleeps = 0;
  const fetcher: FetchLike = () => {
    attempts += 1;
    return Promise.resolve(
      attempts === 1
        ? jsonResponse({ error: "temporary" }, 503)
        : jsonResponse(canonicalPayload()),
    );
  };

  const result = await fetchSalonosStats(config, {
    fetcher,
    sleep: () => {
      sleeps += 1;
      return Promise.resolve();
    },
  });

  assert.equal(result.provider.id, providerId);
  assert.equal(attempts, 2);
  assert.equal(sleeps, 1);
});

Deno.test("maps exhausted network failures without exposing details", async () => {
  let attempts = 0;
  const fetcher: FetchLike = () => {
    attempts += 1;
    return Promise.reject(new Error("secret internal network detail"));
  };

  await assert.rejects(
    () => fetchSalonosStats(config, { fetcher, sleep: noSleep }),
    (error: unknown) =>
      error instanceof SalonosIntegrationError &&
      error.code === "UPSTREAM_NETWORK_ERROR" &&
      !error.message.includes("secret internal"),
  );
  assert.equal(attempts, 2);
});

Deno.test("maps an aborted request to timeout", async () => {
  const fetcher: FetchLike = () =>
    Promise.reject(new DOMException("timed out", "AbortError"));

  await assert.rejects(
    () =>
      fetchSalonosStats(
        { ...config, attempts: 1 },
        { fetcher, sleep: noSleep },
      ),
    (error: unknown) =>
      error instanceof SalonosIntegrationError &&
      error.code === "UPSTREAM_TIMEOUT",
  );
});

Deno.test("rejects non-JSON and oversized responses", async () => {
  const nonJson: FetchLike = () =>
    Promise.resolve(
      new Response("not json", {
        status: 200,
        headers: { "Content-Type": "text/plain" },
      }),
    );
  await assert.rejects(
    () => fetchSalonosStats(config, { fetcher: nonJson, sleep: noSleep }),
    (error: unknown) =>
      error instanceof SalonosIntegrationError &&
      error.code === "CONTRACT_INVALID",
  );

  const oversized: FetchLike = () =>
    Promise.resolve(
      new Response("{}", {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Content-Length": String(256 * 1024 + 1),
        },
      }),
    );
  await assert.rejects(
    () => fetchSalonosStats(config, { fetcher: oversized, sleep: noSleep }),
    (error: unknown) =>
      error instanceof SalonosIntegrationError &&
      error.code === "RESPONSE_TOO_LARGE",
  );
});

Deno.test("rejects insecure or malformed configuration before fetch", async () => {
  let fetched = false;
  const fetcher: FetchLike = () => {
    fetched = true;
    return Promise.resolve(jsonResponse(canonicalPayload()));
  };

  await assert.rejects(
    () =>
      fetchSalonosStats(
        { ...config, baseUrl: "http://servishub.example" },
        { fetcher, sleep: noSleep },
      ),
    (error: unknown) =>
      error instanceof SalonosIntegrationError &&
      error.code === "CONFIG_INVALID",
  );
  assert.equal(fetched, false);
});

Deno.test("handler rejects non-POST requests before authorization", async () => {
  let authorized = false;
  const handler = createHandler({
    authorize: () => {
      authorized = true;
      return Promise.resolve({ ok: true });
    },
  });

  const response = await handler(new Request("https://base44.example/function"));
  assert.equal(response.status, 405);
  assert.equal(response.headers.get("allow"), "POST");
  assert.equal(authorized, false);
});

Deno.test("handler rejects anonymous and non-admin callers before fetch", async () => {
  for (
    const authResult of [
      { ok: false as const, status: 401 as const, code: "UNAUTHENTICATED" as const },
      { ok: false as const, status: 403 as const, code: "FORBIDDEN" as const },
    ]
  ) {
    let fetched = false;
    const handler = createHandler({
      authorize: () => Promise.resolve(authResult),
      fetcher: () => {
        fetched = true;
        return Promise.resolve(jsonResponse(canonicalPayload()));
      },
    });

    const response = await handler(
      new Request("https://base44.example/function", { method: "POST" }),
    );
    assert.equal(response.status, authResult.status);
    assert.equal(fetched, false);
  }
});

Deno.test("authenticated handler uses fixed environment tenant and no-store response", async () => {
  const env = new Map([
    ["SALONOS_API_BASE_URL", config.baseUrl],
    ["SALONOS_PROVIDER_ID", config.providerId],
    ["SALONOS_API_TOKEN", config.apiToken],
  ]);
  const handler = createHandler({
    authorize: () => Promise.resolve({ ok: true }),
    getEnv: (name) => env.get(name),
    fetcher: () => Promise.resolve(jsonResponse(canonicalPayload())),
    sleep: noSleep,
  });

  const response = await handler(
    new Request("https://base44.example/function", {
      method: "POST",
      body: JSON.stringify({ providerId: "attacker-controlled-provider" }),
    }),
  );
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(payload.provider.id, providerId);
  assert.equal("recentLogs" in payload, false);
});
