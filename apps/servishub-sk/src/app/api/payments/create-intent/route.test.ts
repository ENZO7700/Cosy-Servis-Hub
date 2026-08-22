import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

const getSessionProfile = vi.fn();
const findFirst = vi.fn();
const transaction = vi.fn();
const paymentIntentsCreate = vi.fn();
const paymentIntentsRetrieve = vi.fn();

vi.mock("@/lib/auth/session", () => ({
  getSessionProfile: (...args: unknown[]) => getSessionProfile(...args),
}));

vi.mock("@/lib/prisma", () => ({
  prisma: {
    booking: {
      findFirst: (...args: unknown[]) => findFirst(...args),
      update: vi.fn(async (args: unknown) => args),
    },
    $transaction: (...args: unknown[]) => transaction(...args),
    payment: { upsert: vi.fn(async (args: unknown) => args) },
  },
}));

vi.mock("@/lib/stripe/client", () => ({
  getStripe: () => ({
    paymentIntents: {
      create: (...args: unknown[]) => paymentIntentsCreate(...args),
      retrieve: (...args: unknown[]) => paymentIntentsRetrieve(...args),
    },
  }),
  applicationFeeAmountCents: (cents: number) => Math.round(cents * 0.15),
}));

import { POST } from "./route";

describe("POST /api/payments/create-intent", () => {
  const original = process.env.DATABASE_URL;

  beforeEach(() => {
    getSessionProfile.mockReset();
    findFirst.mockReset();
    transaction.mockReset();
    paymentIntentsCreate.mockReset();
    paymentIntentsRetrieve.mockReset();
  });

  afterEach(() => {
    if (original === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = original;
  });

  it("returns 503 without DB", async () => {
    delete process.env.DATABASE_URL;
    const res = await POST(
      new Request("http://localhost/api/payments/create-intent", {
        method: "POST",
        body: JSON.stringify({ bookingId: "bk" }),
      }),
    );
    expect(res.status).toBe(503);
  });

  it("returns 401 without profile", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    getSessionProfile.mockResolvedValue(null);
    const res = await POST(
      new Request("http://localhost/api/payments/create-intent", {
        method: "POST",
        body: JSON.stringify({ bookingId: "bk" }),
      }),
    );
    expect(res.status).toBe(401);
  });

  it("returns 400 for bad JSON", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    getSessionProfile.mockResolvedValue({ id: "cust_1" });
    const res = await POST(
      new Request("http://localhost/api/payments/create-intent", {
        method: "POST",
        body: "not-json",
      }),
    );
    expect(res.status).toBe(400);
  });

  it("returns 404 when booking missing", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    getSessionProfile.mockResolvedValue({ id: "cust_1" });
    findFirst.mockResolvedValue(null);
    const res = await POST(
      new Request("http://localhost/api/payments/create-intent", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ bookingId: "missing" }),
      }),
    );
    expect(res.status).toBe(404);
  });

  it("creates intent with application fee", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    getSessionProfile.mockResolvedValue({ id: "cust_1" });
    findFirst.mockResolvedValue({
      id: "bk_1",
      customerId: "cust_1",
      providerId: "prov_1",
      status: "PENDING",
      priceAmount: 100,
      currency: "EUR",
      stripePaymentIntentId: null,
      payment: null,
      provider: { id: "prov_1", stripeAccountId: "acct_1", businessName: "BA" },
    });
    paymentIntentsCreate.mockResolvedValue({
      id: "pi_1",
      client_secret: "secret",
    });
    // Route uses interactive array form: $transaction([promise, promise])
    transaction.mockImplementation(async (ops: Promise<unknown>[]) =>
      Promise.all(ops),
    );

    const res = await POST(
      new Request("http://localhost/api/payments/create-intent", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ bookingId: "bk_1" }),
      }),
    );
    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.paymentIntentId).toBe("pi_1");
    expect(json.applicationFeeAmount).toBe(1500);
    expect(paymentIntentsCreate).toHaveBeenCalled();
  });

  it("reuses existing payment intent", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    getSessionProfile.mockResolvedValue({ id: "cust_1" });
    findFirst.mockResolvedValue({
      id: "bk_1",
      customerId: "cust_1",
      providerId: "prov_1",
      status: "PENDING",
      priceAmount: 100,
      currency: "EUR",
      stripePaymentIntentId: "pi_existing",
      payment: { id: "pay_1" },
      provider: { id: "prov_1", stripeAccountId: "acct_1", businessName: "BA" },
    });
    paymentIntentsRetrieve.mockResolvedValue({
      id: "pi_existing",
      client_secret: "secret2",
    });

    const res = await POST(
      new Request("http://localhost/api/payments/create-intent", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ bookingId: "bk_1" }),
      }),
    );
    expect(res.status).toBe(200);
    expect(paymentIntentsCreate).not.toHaveBeenCalled();
    expect(paymentIntentsRetrieve).toHaveBeenCalledWith("pi_existing");
  });
});
