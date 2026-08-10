import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

const constructEvent = vi.fn();
const paymentUpsert = vi.fn();
const bookingUpdate = vi.fn();

vi.mock("@/lib/stripe/client", () => ({
  getStripe: () => ({
    webhooks: {
      constructEvent: (...args: unknown[]) => constructEvent(...args),
    },
  }),
}));

vi.mock("@/lib/prisma", () => ({
  prisma: {
    $transaction: async (fn: (tx: {
      payment: { upsert: typeof paymentUpsert };
      booking: { update: typeof bookingUpdate };
    }) => Promise<unknown>) =>
      fn({
        payment: { upsert: paymentUpsert },
        booking: { update: bookingUpdate },
      }),
  },
}));

import { POST } from "./route";

function intentEvent(
  type: string,
  status: string,
  metadata: Record<string, string> = { bookingId: "bk_1" },
) {
  return {
    type,
    data: {
      object: {
        id: "pi_1",
        status,
        amount: 10000,
        currency: "eur",
        application_fee_amount: 1500,
        created: Math.floor(Date.now() / 1000),
        latest_charge: "ch_1",
        metadata,
      },
    },
  };
}

describe("POST /api/payments/webhook", () => {
  const originalDb = process.env.DATABASE_URL;
  const originalSecret = process.env.STRIPE_WEBHOOK_SECRET;

  beforeEach(() => {
    constructEvent.mockReset();
    paymentUpsert.mockReset();
    bookingUpdate.mockReset();
    paymentUpsert.mockResolvedValue({});
    bookingUpdate.mockResolvedValue({});
  });

  afterEach(() => {
    if (originalDb === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = originalDb;
    if (originalSecret === undefined) delete process.env.STRIPE_WEBHOOK_SECRET;
    else process.env.STRIPE_WEBHOOK_SECRET = originalSecret;
  });

  it("returns 503 without DB", async () => {
    delete process.env.DATABASE_URL;
    const res = await POST(
      new Request("http://localhost/api/payments/webhook", {
        method: "POST",
        body: "{}",
      }),
    );
    expect(res.status).toBe(503);
  });

  it("returns 503 without webhook secret", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    delete process.env.STRIPE_WEBHOOK_SECRET;
    const res = await POST(
      new Request("http://localhost/api/payments/webhook", {
        method: "POST",
        body: "{}",
        headers: { "stripe-signature": "sig" },
      }),
    );
    expect(res.status).toBe(503);
  });

  it("returns 400 without signature", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    process.env.STRIPE_WEBHOOK_SECRET = "whsec_test";
    const res = await POST(
      new Request("http://localhost/api/payments/webhook", {
        method: "POST",
        body: "{}",
      }),
    );
    expect(res.status).toBe(400);
  });

  it("returns 400 on invalid signature", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    process.env.STRIPE_WEBHOOK_SECRET = "whsec_test";
    constructEvent.mockImplementation(() => {
      throw new Error("bad sig");
    });
    const res = await POST(
      new Request("http://localhost/api/payments/webhook", {
        method: "POST",
        body: "{}",
        headers: { "stripe-signature": "bad" },
      }),
    );
    expect(res.status).toBe(400);
  });

  it("marks booking CONFIRMED on payment_intent.succeeded", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    process.env.STRIPE_WEBHOOK_SECRET = "whsec_test";
    constructEvent.mockReturnValue(
      intentEvent("payment_intent.succeeded", "succeeded"),
    );

    const res = await POST(
      new Request("http://localhost/api/payments/webhook", {
        method: "POST",
        body: "{}",
        headers: { "stripe-signature": "sig" },
      }),
    );
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ received: true });
    expect(paymentUpsert).toHaveBeenCalled();
    expect(bookingUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: "bk_1" },
        data: expect.objectContaining({ status: "CONFIRMED" }),
      }),
    );
  });

  it("marks booking CANCELLED on payment_intent.canceled", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    process.env.STRIPE_WEBHOOK_SECRET = "whsec_test";
    constructEvent.mockReturnValue(
      intentEvent("payment_intent.canceled", "canceled"),
    );

    const res = await POST(
      new Request("http://localhost/api/payments/webhook", {
        method: "POST",
        body: "{}",
        headers: { "stripe-signature": "sig" },
      }),
    );
    expect(res.status).toBe(200);
    expect(bookingUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: "CANCELLED" }),
      }),
    );
  });

  it("tolerates missing bookingId metadata", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    process.env.STRIPE_WEBHOOK_SECRET = "whsec_test";
    constructEvent.mockReturnValue(
      intentEvent("payment_intent.succeeded", "succeeded", {}),
    );

    const res = await POST(
      new Request("http://localhost/api/payments/webhook", {
        method: "POST",
        body: "{}",
        headers: { "stripe-signature": "sig" },
      }),
    );
    expect(res.status).toBe(200);
    expect(paymentUpsert).not.toHaveBeenCalled();
  });
});
