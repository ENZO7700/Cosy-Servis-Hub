import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const signInWithPassword = vi.fn();
const signUp = vi.fn();
const signOut = vi.fn();
const ensureProfileAfterSignup = vi.fn();
const redirect = vi.fn((url: string) => {
  throw new Error(`NEXT_REDIRECT:${url}`);
});

vi.mock("next/navigation", () => ({
  redirect: (url: string) => redirect(url),
}));

vi.mock("@/lib/auth/session", () => ({
  ensureProfileAfterSignup: (...args: unknown[]) =>
    (ensureProfileAfterSignup as (...a: unknown[]) => unknown)(...args),
}));

vi.mock("@/lib/supabase/server", () => ({
  createClient: async () => ({
    auth: {
      signInWithPassword: (...args: unknown[]) => (signInWithPassword as (...a: unknown[]) => unknown)(...args),
      signUp: (...args: unknown[]) => (signUp as (...a: unknown[]) => unknown)(...args),
      signOut: (...args: unknown[]) => (signOut as (...a: unknown[]) => unknown)(...args),
    },
  }),
}));

import { loginAction, logoutAction, signupAction } from "./actions";

function form(data: Record<string, string>) {
  const fd = new FormData();
  for (const [k, v] of Object.entries(data)) fd.set(k, v);
  return fd;
}

describe("auth actions", () => {
  const originalUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const originalKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const originalDb = process.env.DATABASE_URL;

  beforeEach(() => {
    signInWithPassword.mockReset();
    signUp.mockReset();
    signOut.mockReset();
    ensureProfileAfterSignup.mockReset();
    redirect.mockClear();
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

  it("errors when auth env missing", async () => {
    delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    const result = await loginAction(
      { status: "idle" },
      form({ email: "a@b.sk", password: "secret1" }),
    );
    expect(result.status).toBe("error");
    expect(result.message).toMatch(/Supabase Auth/);
  });

  it("rejects invalid login fields", async () => {
    const result = await loginAction(
      { status: "idle" },
      form({ email: "bad", password: "1" }),
    );
    expect(result.status).toBe("error");
    expect(result.fieldErrors).toBeDefined();
  });

  it("blocks open redirects via next", async () => {
    signInWithPassword.mockResolvedValue({
      data: { user: { id: "u1", email: "a@b.sk", user_metadata: {} } },
      error: null,
    });
    ensureProfileAfterSignup.mockResolvedValue({});

    await expect(
      loginAction(
        { status: "idle" },
        form({
          email: "a@b.sk",
          password: "secret1",
          next: "//evil.com",
        }),
      ),
    ).rejects.toThrow(/NEXT_REDIRECT:\/$/);
  });

  it("redirects PROVIDER signup to /pro", async () => {
    signUp.mockResolvedValue({
      data: {
        session: { access_token: "t" },
        user: { id: "u1", email: "pro@b.sk" },
      },
      error: null,
    });
    ensureProfileAfterSignup.mockResolvedValue({});

    await expect(
      signupAction(
        { status: "idle" },
        form({
          fullName: "Jan Pro",
          email: "pro@b.sk",
          password: "secret1",
          role: "PROVIDER",
          promoCode: "",
        }),
      ),
    ).rejects.toThrow(/NEXT_REDIRECT:\/pro$/);
  });

  it("returns success when email confirmation is required", async () => {
    signUp.mockResolvedValue({
      data: { session: null, user: { id: "u1" } },
      error: null,
    });
    const result = await signupAction(
      { status: "idle" },
      form({
        fullName: "Jan",
        email: "jan@b.sk",
        password: "secret1",
        role: "CUSTOMER",
        promoCode: "",
      }),
    );
    expect(result.status).toBe("success");
    expect(result.message).toMatch(/email/);
  });

  it("logout redirects home", async () => {
    signOut.mockResolvedValue({});
    await expect(logoutAction()).rejects.toThrow(/NEXT_REDIRECT:\/$/);
  });
});
