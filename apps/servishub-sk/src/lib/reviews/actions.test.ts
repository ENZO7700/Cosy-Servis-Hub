import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("next/cache", () => ({
  revalidatePath: vi.fn(),
}));

const getSessionProfile = vi.fn();
const createReviewForCompletedBooking = vi.fn();

vi.mock("@/lib/auth/session", () => ({
  getSessionProfile: (...args: unknown[]) => getSessionProfile(...args),
}));

vi.mock("@/lib/data/reviews", () => ({
  createReviewForCompletedBooking: (...args: unknown[]) =>
    createReviewForCompletedBooking(...args),
}));

import { submitReview } from "./actions";

function form(data: Record<string, string>) {
  const fd = new FormData();
  for (const [k, v] of Object.entries(data)) fd.set(k, v);
  return fd;
}

describe("submitReview", () => {
  const original = process.env.DATABASE_URL;

  beforeEach(() => {
    getSessionProfile.mockReset();
    createReviewForCompletedBooking.mockReset();
  });

  afterEach(() => {
    if (original === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = original;
  });

  it("errors when DB is down", async () => {
    delete process.env.DATABASE_URL;
    const result = await submitReview(
      { status: "idle" },
      form({ bookingId: "bk", rating: "5" }),
    );
    expect(result.status).toBe("error");
  });

  it("requires auth", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    getSessionProfile.mockResolvedValue(null);
    const result = await submitReview(
      { status: "idle" },
      form({ bookingId: "bk", rating: "5" }),
    );
    expect(result.message).toMatch(/prihláste/);
  });

  it("rejects invalid rating", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    getSessionProfile.mockResolvedValue({ id: "cust_1" });
    const result = await submitReview(
      { status: "idle" },
      form({ bookingId: "bk", rating: "9" }),
    );
    expect(result.status).toBe("error");
    expect(createReviewForCompletedBooking).not.toHaveBeenCalled();
  });

  it("succeeds for rating 1–5", async () => {
    process.env.DATABASE_URL = "postgresql://localhost/test";
    getSessionProfile.mockResolvedValue({ id: "cust_1" });
    createReviewForCompletedBooking.mockResolvedValue({ id: "rv_1" });
    const result = await submitReview(
      { status: "idle" },
      form({
        bookingId: "bk_1",
        rating: "5",
        providerSlug: "firma",
        comment: "Top",
      }),
    );
    expect(result.status).toBe("success");
    expect(createReviewForCompletedBooking).toHaveBeenCalled();
  });
});
