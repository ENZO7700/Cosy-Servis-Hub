import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const leadCreate = vi.fn();

vi.mock("@/lib/prisma", () => ({
  prisma: {
    lead: {
      create: (...args: unknown[]) => leadCreate(...args),
    },
  },
}));

import { joinWaitlist } from "./waitlist-actions";

function form(data: Record<string, string>) {
  const fd = new FormData();
  for (const [k, v] of Object.entries(data)) fd.set(k, v);
  return fd;
}

describe("joinWaitlist", () => {
  const original = process.env.DATABASE_URL;

  beforeEach(() => {
    leadCreate.mockReset();
  });

  afterEach(() => {
    if (original === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = original;
  });

  it("errors when DB is down", async () => {
    delete process.env.DATABASE_URL;
    const result = await joinWaitlist(
      { status: "idle" },
      form({ email: "a@b.sk" }),
    );
    expect(result.status).toBe("error");
    expect(result.message).toMatch(/DATABASE_URL/);
  });

  it("rejects invalid email", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    const result = await joinWaitlist(
      { status: "idle" },
      form({ email: "not-an-email" }),
    );
    expect(result.status).toBe("error");
    expect(leadCreate).not.toHaveBeenCalled();
  });

  it("creates a waitlist lead", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    leadCreate.mockResolvedValue({ id: "lead_1" });
    const result = await joinWaitlist(
      { status: "idle" },
      form({ email: "jan@example.sk", city: "Bratislava", promoCode: "EARLY" }),
    );
    expect(result.status).toBe("success");
    expect(leadCreate).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          source: "waitlist",
          contactEmail: "jan@example.sk",
          city: "Bratislava",
        }),
      }),
    );
  });
});
