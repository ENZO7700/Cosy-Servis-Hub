import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const exchangeCodeForSession = vi.fn();
const ensureProfileAfterSignup = vi.fn();

vi.mock("@/lib/auth/session", () => ({
  ensureProfileAfterSignup: (...args: unknown[]) =>
    ensureProfileAfterSignup(...args),
}));

vi.mock("@/lib/supabase/server", () => ({
  createClient: async () => ({
    auth: {
      exchangeCodeForSession: (...args: unknown[]) =>
        exchangeCodeForSession(...args),
    },
  }),
}));

import { GET } from "./route";

describe("GET /auth/callback", () => {
  const originalUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const originalKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const originalDb = process.env.DATABASE_URL;

  beforeEach(() => {
    exchangeCodeForSession.mockReset();
    ensureProfileAfterSignup.mockReset();
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "anon";
    process.env.DATABASE_URL = "postgresql://localhost/test";
  });

  afterEach(() => {
    if (originalUrl === undefined) delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    else process.env.NEXT_PUBLIC_SUPABASE_URL = originalUrl;
    if (originalKey === undefined) delete process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    else process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = originalKey;
    if (originalDb === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = originalDb;
  });

  it("redirects when code is missing", async () => {
    const res = await GET(
      new Request("http://localhost:3000/auth/callback") as never,
    );
    expect(res.status).toBe(307);
    expect(res.headers.get("location")).toContain("/login?error=missing_code");
  });

  it("redirects when exchange fails", async () => {
    exchangeCodeForSession.mockResolvedValue({
      data: { user: null },
      error: { message: "bad" },
    });
    const res = await GET(
      new Request("http://localhost:3000/auth/callback?code=abc") as never,
    );
    expect(res.headers.get("location")).toContain("error=auth_callback");
  });

  it("upserts profile and redirects PROVIDER to /pro", async () => {
    exchangeCodeForSession.mockResolvedValue({
      data: {
        user: {
          id: "u1",
          email: "pro@b.sk",
          user_metadata: { role: "PROVIDER", full_name: "Jan" },
        },
      },
      error: null,
    });
    ensureProfileAfterSignup.mockResolvedValue({});

    const res = await GET(
      new Request("http://localhost:3000/auth/callback?code=ok&next=/") as never,
    );
    expect(ensureProfileAfterSignup).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: "u1",
        role: "PROVIDER",
      }),
    );
    expect(res.headers.get("location")).toBe("http://localhost:3000/pro");
  });

  it("rejects open-redirect next values", async () => {
    exchangeCodeForSession.mockResolvedValue({
      data: {
        user: {
          id: "u1",
          email: "a@b.sk",
          user_metadata: { role: "CUSTOMER" },
        },
      },
      error: null,
    });
    ensureProfileAfterSignup.mockResolvedValue({});

    const res = await GET(
      new Request(
        "http://localhost:3000/auth/callback?code=ok&next=//evil.com",
      ) as never,
    );
    expect(res.headers.get("location")).toBe("http://localhost:3000/");
  });
});
