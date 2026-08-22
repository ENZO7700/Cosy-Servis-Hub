import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const getUser = vi.fn();
const findUnique = vi.fn();
const upsert = vi.fn();
const redirect = vi.fn((url: string) => {
  throw new Error(`NEXT_REDIRECT:${url}`);
});

vi.mock("next/navigation", () => ({
  redirect: (url: string) => redirect(url),
}));

vi.mock("@/lib/supabase/server", () => ({
  createClient: async () => ({
    auth: { getUser: (...args: unknown[]) => (getUser as (...a: unknown[]) => unknown)(...args) },
  }),
}));

vi.mock("@/lib/prisma", () => ({
  prisma: {
    profile: {
      findUnique: (...args: unknown[]) => (findUnique as (...a: unknown[]) => unknown)(...args),
      upsert: (...args: unknown[]) => (upsert as (...a: unknown[]) => unknown)(...args),
    },
  },
}));

import {
  ensureProfileAfterSignup,
  getSessionUser,
  requireRole,
} from "./session";

describe("getSessionUser", () => {
  const originalUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const originalKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  afterEach(() => {
    if (originalUrl === undefined) delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    else process.env.NEXT_PUBLIC_SUPABASE_URL = originalUrl;
    if (originalKey === undefined) delete process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    else process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = originalKey;
  });

  it("returns null when auth env is missing", async () => {
    delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    delete process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    await expect(getSessionUser()).resolves.toBeNull();
  });

  it("returns user from Supabase", async () => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "anon";
    getUser.mockResolvedValue({ data: { user: { id: "u1" } } });
    await expect(getSessionUser()).resolves.toEqual({ id: "u1" });
  });
});

describe("ensureProfileAfterSignup", () => {
  beforeEach(() => {
    upsert.mockReset();
  });

  it("upserts profile with role and promo", async () => {
    upsert.mockResolvedValue({ id: "p1", userId: "u1" });
    await ensureProfileAfterSignup({
      userId: "u1",
      email: "a@b.sk",
      fullName: "Jan",
      role: "PROVIDER",
      promoCode: "EARLY",
    });
    expect(upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId: "u1" },
        create: expect.objectContaining({
          email: "a@b.sk",
          role: "PROVIDER",
          promoCode: "EARLY",
        }),
      }),
    );
  });
});

describe("requireRole", () => {
  const originalUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const originalKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  beforeEach(() => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "anon";
    getUser.mockReset();
    findUnique.mockReset();
    redirect.mockClear();
  });

  afterEach(() => {
    if (originalUrl === undefined) delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    else process.env.NEXT_PUBLIC_SUPABASE_URL = originalUrl;
    if (originalKey === undefined) delete process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    else process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = originalKey;
  });

  it("redirects to login when unauthenticated", async () => {
    getUser.mockResolvedValue({ data: { user: null } });
    await expect(requireRole("PROVIDER", { next: "/pro" })).rejects.toThrow(
      /NEXT_REDIRECT:\/login\?next=%2Fpro/,
    );
  });

  it("redirects home when role is not allowed", async () => {
    getUser.mockResolvedValue({ data: { user: { id: "u1" } } });
    findUnique.mockResolvedValue({ id: "p1", role: "CUSTOMER" });
    await expect(requireRole("ADMIN")).rejects.toThrow(/NEXT_REDIRECT:\/$/);
  });

  it("returns profile when role matches", async () => {
    getUser.mockResolvedValue({ data: { user: { id: "u1" } } });
    findUnique.mockResolvedValue({ id: "p1", role: "PROVIDER" });
    await expect(requireRole(["PROVIDER", "ADMIN"])).resolves.toEqual({
      id: "p1",
      role: "PROVIDER",
    });
  });
});
