import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

describe("stripe client helpers", () => {
  const originalEnv = { ...process.env };

  beforeEach(() => {
    vi.resetModules();
    process.env = { ...originalEnv };
    delete process.env.STRIPE_SECRET_KEY;
    delete process.env.COMMISSION_PERCENT;
  });

  afterEach(() => {
    process.env = { ...originalEnv };
  });

  it("defaults commission to 15 and clamps invalid values", async () => {
    const { getCommissionPercent } = await import("./client");
    expect(getCommissionPercent()).toBe(15);

    process.env.COMMISSION_PERCENT = "20";
    vi.resetModules();
    const mod20 = await import("./client");
    expect(mod20.getCommissionPercent()).toBe(20);

    process.env.COMMISSION_PERCENT = "not-a-number";
    vi.resetModules();
    const modBad = await import("./client");
    expect(modBad.getCommissionPercent()).toBe(15);

    process.env.COMMISSION_PERCENT = "150";
    vi.resetModules();
    const modHigh = await import("./client");
    expect(modHigh.getCommissionPercent()).toBe(15);
  });

  it("rounds application fee cents", async () => {
    const { applicationFeeAmountCents } = await import("./client");
    expect(applicationFeeAmountCents(10000, 15)).toBe(1500);
    expect(applicationFeeAmountCents(9999, 15)).toBe(1500);
    expect(applicationFeeAmountCents(10001, 10)).toBe(1000);
  });

  it("throws when STRIPE_SECRET_KEY is missing", async () => {
    const { getStripe } = await import("./client");
    expect(() => getStripe()).toThrow(/STRIPE_SECRET_KEY/);
  });
});
