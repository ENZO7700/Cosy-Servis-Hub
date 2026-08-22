import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

vi.mock("@/lib/supabase/middleware", () => ({
  updateSession: vi.fn(),
}));

import { updateSession } from "@/lib/supabase/middleware";
import { middleware } from "./middleware";

const mockedUpdateSession = vi.mocked(updateSession);

describe("middleware", () => {
  beforeEach(() => {
    mockedUpdateSession.mockReset();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("redirects unauthenticated /pro to login", async () => {
    const req = new NextRequest("http://localhost:3000/pro/profil");
    mockedUpdateSession.mockResolvedValue({
      supabaseResponse: new Response(null, { status: 200 }) as never,
      user: null,
    });

    const res = await middleware(req);
    expect(res.status).toBe(307);
    expect(res.headers.get("location")).toContain("/login?next=");
    expect(res.headers.get("location")).toContain("%2Fpro%2Fprofil");
  });

  it("redirects unauthenticated /admin", async () => {
    const req = new NextRequest("http://localhost:3000/admin");
    mockedUpdateSession.mockResolvedValue({
      supabaseResponse: new Response(null, { status: 200 }) as never,
      user: null,
    });

    const res = await middleware(req);
    expect(res.status).toBe(307);
    expect(res.headers.get("location")).toContain("/login");
  });

  it("passes public paths through", async () => {
    const passthrough = new Response("ok", { status: 200 }) as never;
    const req = new NextRequest("http://localhost:3000/hladat");
    mockedUpdateSession.mockResolvedValue({
      supabaseResponse: passthrough,
      user: null,
    });

    const res = await middleware(req);
    expect(res).toBe(passthrough);
  });

  it("allows authenticated /pro", async () => {
    const passthrough = new Response("ok", { status: 200 }) as never;
    const req = new NextRequest("http://localhost:3000/pro");
    mockedUpdateSession.mockResolvedValue({
      supabaseResponse: passthrough,
      user: { id: "u1" } as never,
    });

    const res = await middleware(req);
    expect(res).toBe(passthrough);
  });
});
