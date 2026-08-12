import { createClientFromRequest } from "npm:@base44/sdk@0.8.41";
import { type AuthResult, createHandler } from "./reader.ts";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function authorizeBase44Admin(request: Request): Promise<AuthResult> {
  try {
    const base44 = createClientFromRequest(request);
    const user: unknown = await base44.auth.me();
    if (!isRecord(user)) {
      return { ok: false, status: 401, code: "UNAUTHENTICATED" };
    }
    if (user.role !== "admin" && user.is_service !== true) {
      return { ok: false, status: 403, code: "FORBIDDEN" };
    }
    return { ok: true };
  } catch {
    return { ok: false, status: 401, code: "UNAUTHENTICATED" };
  }
}

Deno.serve(createHandler({ authorize: authorizeBase44Admin }));
