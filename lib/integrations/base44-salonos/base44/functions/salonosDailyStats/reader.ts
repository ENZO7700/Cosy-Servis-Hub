const BUSINESS_TYPES = [
  "BEAUTY",
  "HEALTH_WELLNESS",
  "HOME_SERVICES",
  "AUTOMOTIVE",
  "PROFESSIONAL_SERVICES",
  "OTHER",
] as const;

const TRANSIENT_STATUSES = new Set([408, 429, 500, 502, 503, 504]);
const MAX_RESPONSE_BYTES = 256 * 1024;
const DEFAULT_TIMEOUT_MS = 10_000;
const DEFAULT_ATTEMPTS = 2;

export type BusinessType = (typeof BUSINESS_TYPES)[number];

export type SalonosStats = {
  provider: {
    id: string;
    businessName: string;
    businessType: BusinessType;
  };
  totalAiRevenue: number;
  breakdown: {
    returnEngine: number;
    slotFiller: number;
    noShowGuards: number;
  };
  dailyActions: Array<{
    id: string;
    title: string;
    detail: string;
    count: number;
  }>;
  currency: "EUR";
  periodStart: string;
};

export type ReaderConfig = {
  baseUrl: string;
  providerId: string;
  apiToken: string;
  timeoutMs?: number;
  attempts?: number;
};

export type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export type ReaderDependencies = {
  fetcher?: FetchLike;
  sleep?: (delayMs: number) => Promise<void>;
};

export type AuthResult =
  | { ok: true }
  | { ok: false; status: 401 | 403; code: "UNAUTHENTICATED" | "FORBIDDEN" };

export type HandlerDependencies = ReaderDependencies & {
  authorize: (request: Request) => Promise<AuthResult>;
  getEnv?: (name: string) => string | undefined;
};

export type IntegrationErrorCode =
  | "CONFIG_INVALID"
  | "UPSTREAM_UNAUTHORIZED"
  | "UPSTREAM_FORBIDDEN"
  | "UPSTREAM_NOT_FOUND"
  | "UPSTREAM_UNAVAILABLE"
  | "UPSTREAM_ERROR"
  | "UPSTREAM_TIMEOUT"
  | "UPSTREAM_NETWORK_ERROR"
  | "RESPONSE_TOO_LARGE"
  | "CONTRACT_INVALID"
  | "TENANT_MISMATCH";

export class SalonosIntegrationError extends Error {
  constructor(
    readonly code: IntegrationErrorCode,
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "SalonosIntegrationError";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requiredString(
  value: unknown,
  field: string,
  maxLength: number,
): string {
  if (typeof value !== "string") {
    throw contractError(`${field} must be a string.`);
  }
  const normalized = value.trim();
  if (!normalized || normalized.length > maxLength) {
    throw contractError(`${field} has an invalid length.`);
  }
  return normalized;
}

function finiteNumber(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw contractError(`${field} must be a finite number.`);
  }
  return value;
}

function nonNegativeInteger(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) {
    throw contractError(`${field} must be a non-negative integer.`);
  }
  return value;
}

function contractError(message: string): SalonosIntegrationError {
  return new SalonosIntegrationError("CONTRACT_INVALID", message, 502);
}

function validateBusinessType(value: unknown): BusinessType {
  if (
    typeof value !== "string" ||
    !BUSINESS_TYPES.includes(value as BusinessType)
  ) {
    throw contractError("provider.businessType is not supported.");
  }
  return value as BusinessType;
}

function validatePeriodStart(value: unknown): string {
  const periodStart = requiredString(value, "periodStart", 64);
  if (Number.isNaN(Date.parse(periodStart))) {
    throw contractError("periodStart must be an ISO-compatible date string.");
  }
  return periodStart;
}

export function parseSalonosStats(
  value: unknown,
  expectedProviderId: string,
): SalonosStats {
  if (!isRecord(value)) throw contractError("Response must be an object.");
  if (!isRecord(value.provider)) {
    throw contractError("provider must be an object.");
  }
  if (!isRecord(value.breakdown)) {
    throw contractError("breakdown must be an object.");
  }
  if (!Array.isArray(value.dailyActions) || value.dailyActions.length > 100) {
    throw contractError("dailyActions must be an array with at most 100 items.");
  }

  const providerId = requiredString(value.provider.id, "provider.id", 128);
  if (providerId !== expectedProviderId) {
    throw new SalonosIntegrationError(
      "TENANT_MISMATCH",
      "SALONOS returned a different provider than requested.",
      502,
    );
  }

  const seenActionIds = new Set<string>();
  const dailyActions = value.dailyActions.map((item, index) => {
    if (!isRecord(item)) {
      throw contractError(`dailyActions[${index}] must be an object.`);
    }
    const id = requiredString(item.id, `dailyActions[${index}].id`, 128);
    if (seenActionIds.has(id)) {
      throw contractError(`dailyActions contains duplicate id ${id}.`);
    }
    seenActionIds.add(id);
    return {
      id,
      title: requiredString(item.title, `dailyActions[${index}].title`, 200),
      detail: requiredString(item.detail, `dailyActions[${index}].detail`, 500),
      count: nonNegativeInteger(item.count, `dailyActions[${index}].count`),
    };
  });

  const breakdown = {
    returnEngine: finiteNumber(value.breakdown.returnEngine, "breakdown.returnEngine"),
    slotFiller: finiteNumber(value.breakdown.slotFiller, "breakdown.slotFiller"),
    noShowGuards: finiteNumber(
      value.breakdown.noShowGuards,
      "breakdown.noShowGuards",
    ),
  };
  const totalAiRevenue = finiteNumber(value.totalAiRevenue, "totalAiRevenue");
  const calculatedTotal = breakdown.returnEngine + breakdown.slotFiller +
    breakdown.noShowGuards;
  if (Math.abs(totalAiRevenue - calculatedTotal) > 0.01) {
    throw contractError("totalAiRevenue does not match breakdown totals.");
  }
  if (value.currency !== "EUR") {
    throw contractError("currency must be EUR for the SALONOS V1 contract.");
  }

  return {
    provider: {
      id: providerId,
      businessName: requiredString(
        value.provider.businessName,
        "provider.businessName",
        200,
      ),
      businessType: validateBusinessType(value.provider.businessType),
    },
    totalAiRevenue,
    breakdown,
    dailyActions,
    currency: "EUR",
    periodStart: validatePeriodStart(value.periodStart),
  };
}

function validateConfig(config: ReaderConfig): Required<ReaderConfig> {
  let baseUrl: URL;
  try {
    baseUrl = new URL(config.baseUrl);
  } catch {
    throw new SalonosIntegrationError(
      "CONFIG_INVALID",
      "SALONOS_API_BASE_URL must be a valid URL.",
      500,
    );
  }
  if (
    baseUrl.protocol !== "https:" ||
    baseUrl.username ||
    baseUrl.password ||
    baseUrl.search ||
    baseUrl.hash
  ) {
    throw new SalonosIntegrationError(
      "CONFIG_INVALID",
      "SALONOS_API_BASE_URL must be a credential-free HTTPS URL.",
      500,
    );
  }
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]{7,127}$/.test(config.providerId)) {
    throw new SalonosIntegrationError(
      "CONFIG_INVALID",
      "SALONOS_PROVIDER_ID has an invalid format.",
      500,
    );
  }
  if (config.apiToken.trim().length < 16) {
    throw new SalonosIntegrationError(
      "CONFIG_INVALID",
      "SALONOS_API_TOKEN is missing or too short.",
      500,
    );
  }
  const timeoutMs = config.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const attempts = config.attempts ?? DEFAULT_ATTEMPTS;
  if (!Number.isInteger(timeoutMs) || timeoutMs < 1_000 || timeoutMs > 30_000) {
    throw new SalonosIntegrationError(
      "CONFIG_INVALID",
      "timeoutMs must be between 1000 and 30000.",
      500,
    );
  }
  if (!Number.isInteger(attempts) || attempts < 1 || attempts > 2) {
    throw new SalonosIntegrationError(
      "CONFIG_INVALID",
      "attempts must be 1 or 2.",
      500,
    );
  }
  return {
    baseUrl: baseUrl.origin,
    providerId: config.providerId,
    apiToken: config.apiToken.trim(),
    timeoutMs,
    attempts,
  };
}

async function readResponseText(response: Response): Promise<string> {
  const declaredLength = Number(response.headers.get("content-length"));
  if (Number.isFinite(declaredLength) && declaredLength > MAX_RESPONSE_BYTES) {
    throw new SalonosIntegrationError(
      "RESPONSE_TOO_LARGE",
      "SALONOS response exceeded the allowed size.",
      502,
    );
  }
  if (!response.body) return "";

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let totalBytes = 0;
  let body = "";
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > MAX_RESPONSE_BYTES) {
      await reader.cancel();
      throw new SalonosIntegrationError(
        "RESPONSE_TOO_LARGE",
        "SALONOS response exceeded the allowed size.",
        502,
      );
    }
    body += decoder.decode(value, { stream: true });
  }
  return body + decoder.decode();
}

function upstreamStatusError(status: number): SalonosIntegrationError {
  if (status === 401) {
    return new SalonosIntegrationError(
      "UPSTREAM_UNAUTHORIZED",
      "SALONOS rejected the integration credential.",
      502,
    );
  }
  if (status === 403) {
    return new SalonosIntegrationError(
      "UPSTREAM_FORBIDDEN",
      "SALONOS rejected access to this provider.",
      502,
    );
  }
  if (status === 404) {
    return new SalonosIntegrationError(
      "UPSTREAM_NOT_FOUND",
      "SALONOS stats endpoint was not found.",
      502,
    );
  }
  if (TRANSIENT_STATUSES.has(status)) {
    return new SalonosIntegrationError(
      "UPSTREAM_UNAVAILABLE",
      "SALONOS is temporarily unavailable.",
      503,
    );
  }
  return new SalonosIntegrationError(
    "UPSTREAM_ERROR",
    `SALONOS returned HTTP ${status}.`,
    502,
  );
}

export async function fetchSalonosStats(
  inputConfig: ReaderConfig,
  dependencies: ReaderDependencies = {},
): Promise<SalonosStats> {
  const config = validateConfig(inputConfig);
  const fetcher = dependencies.fetcher ?? fetch;
  const sleep = dependencies.sleep ??
    ((delayMs: number) => new Promise((resolve) => setTimeout(resolve, delayMs)));
  const url = new URL(
    `/api/v1/salonos/stats/${encodeURIComponent(config.providerId)}`,
    config.baseUrl,
  );

  let lastError: SalonosIntegrationError | undefined;
  for (let attempt = 1; attempt <= config.attempts; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.timeoutMs);
    try {
      const response = await fetcher(url, {
        method: "GET",
        headers: {
          Accept: "application/json",
          Authorization: `Bearer ${config.apiToken}`,
          "User-Agent": "SALONOS-Base44-Reader/0.1",
        },
        cache: "no-store",
        redirect: "error",
        signal: controller.signal,
      });
      if (!response.ok) {
        response.body?.cancel().catch(() => undefined);
        const statusError = upstreamStatusError(response.status);
        if (TRANSIENT_STATUSES.has(response.status) && attempt < config.attempts) {
          lastError = statusError;
          await sleep(250 * attempt);
          continue;
        }
        throw statusError;
      }
      const contentType = response.headers.get("content-type") ?? "";
      if (!contentType.toLowerCase().includes("application/json")) {
        throw contractError("SALONOS response must use application/json.");
      }
      const rawBody = await readResponseText(response);
      let payload: unknown;
      try {
        payload = JSON.parse(rawBody) as unknown;
      } catch {
        throw contractError("SALONOS response contains invalid JSON.");
      }
      return parseSalonosStats(payload, config.providerId);
    } catch (error) {
      if (error instanceof SalonosIntegrationError) throw error;
      const aborted = controller.signal.aborted ||
        (error instanceof DOMException && error.name === "AbortError");
      lastError = new SalonosIntegrationError(
        aborted ? "UPSTREAM_TIMEOUT" : "UPSTREAM_NETWORK_ERROR",
        aborted ? "SALONOS request timed out." : "SALONOS could not be reached.",
        aborted ? 504 : 503,
      );
      if (attempt < config.attempts) {
        await sleep(250 * attempt);
        continue;
      }
    } finally {
      clearTimeout(timeout);
    }
  }
  throw lastError ??
    new SalonosIntegrationError(
      "UPSTREAM_ERROR",
      "SALONOS request failed.",
      502,
    );
}

function responseHeaders(): HeadersInit {
  return {
    "Cache-Control": "no-store",
    "Content-Type": "application/json; charset=utf-8",
    "X-Content-Type-Options": "nosniff",
  };
}

function errorResponse(
  status: number,
  code: string,
  message: string,
): Response {
  return Response.json(
    { ok: false, error: { code, message } },
    { status, headers: responseHeaders() },
  );
}

export function createHandler(
  dependencies: HandlerDependencies,
): (request: Request) => Promise<Response> {
  const authorize = dependencies.authorize;
  const getEnv = dependencies.getEnv ?? ((name: string) => Deno.env.get(name));

  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return new Response(
        JSON.stringify({
          ok: false,
          error: { code: "METHOD_NOT_ALLOWED", message: "Use POST." },
        }),
        {
          status: 405,
          headers: { ...responseHeaders(), Allow: "POST" },
        },
      );
    }

    const auth = await authorize(request);
    if (!auth.ok) {
      return errorResponse(
        auth.status,
        auth.code,
        auth.status === 401 ? "Authentication required." : "Admin access required.",
      );
    }

    try {
      const stats = await fetchSalonosStats(
        {
          baseUrl: getEnv("SALONOS_API_BASE_URL") ?? "",
          providerId: getEnv("SALONOS_PROVIDER_ID") ?? "",
          apiToken: getEnv("SALONOS_API_TOKEN") ?? "",
        },
        dependencies,
      );
      return Response.json(stats, { status: 200, headers: responseHeaders() });
    } catch (error) {
      if (error instanceof SalonosIntegrationError) {
        return errorResponse(error.status, error.code, error.message);
      }
      return errorResponse(500, "INTERNAL_ERROR", "Unexpected integration error.");
    }
  };
}
