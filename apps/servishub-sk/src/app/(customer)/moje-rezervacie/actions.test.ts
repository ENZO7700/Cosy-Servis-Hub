import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("next/cache", () => ({
  revalidatePath: vi.fn(),
}));

const getSessionProfile = vi.fn();
const cancelCustomerBooking = vi.fn();

vi.mock("@/lib/auth/session", () => ({
  getSessionProfile: (...args: unknown[]) => getSessionProfile(...args),
}));

vi.mock("@/lib/data/bookings", () => ({
  cancelCustomerBooking: (...args: unknown[]) => cancelCustomerBooking(...args),
}));

import { cancelBooking } from "./actions";

describe("cancelBooking", () => {
  const original = process.env.DATABASE_URL;

  beforeEach(() => {
    getSessionProfile.mockReset();
    cancelCustomerBooking.mockReset();
  });

  afterEach(() => {
    if (original === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = original;
  });

  it("errors when DB is down", async () => {
    delete process.env.DATABASE_URL;
    const result = await cancelBooking("bk_1");
    expect(result.status).toBe("error");
    expect(result.message).toMatch(/Databáza/);
  });

  it("errors when unauthenticated", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    getSessionProfile.mockResolvedValue(null);
    const result = await cancelBooking("bk_1");
    expect(result.status).toBe("error");
    expect(result.message).toMatch(/prihláste/);
  });

  it("returns error when cancel fails", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    getSessionProfile.mockResolvedValue({ id: "cust_1" });
    cancelCustomerBooking.mockResolvedValue(false);
    const result = await cancelBooking("bk_1");
    expect(result.status).toBe("error");
  });

  it("succeeds when cancel works", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    getSessionProfile.mockResolvedValue({ id: "cust_1" });
    cancelCustomerBooking.mockResolvedValue(true);
    const result = await cancelBooking("bk_1");
    expect(result.status).toBe("success");
  });
});
