import { beforeEach, describe, expect, it, vi } from "vitest";
import { createTxBookingsStore } from "@/test/mocks/prisma";

const store = createTxBookingsStore();
const providerState = { ratingAvg: 4, ratingCount: 1 };

store.provider.findUniqueOrThrow = async () => ({ ...providerState });
store.provider.update = async (args) => {
  providerState.ratingAvg = args.data.ratingAvg;
  providerState.ratingCount = args.data.ratingCount;
  return args.data;
};

vi.mock("@/lib/prisma", () => ({
  prisma: {
    $transaction: async (fn: (tx: typeof store) => Promise<unknown>) =>
      fn(store),
  },
}));

import {
  ReviewNotAllowedError,
  createReviewForCompletedBooking,
} from "./reviews";

describe("createReviewForCompletedBooking", () => {
  beforeEach(() => {
    store.bookings.length = 0;
    providerState.ratingAvg = 4;
    providerState.ratingCount = 1;
  });

  it("creates review and updates rating aggregates", async () => {
    store.bookings.push({
      id: "bk_1",
      customerId: "cust_1",
      providerId: "prov_1",
      serviceId: "svc_1",
      status: "COMPLETED",
      scheduledAt: new Date(),
      durationMin: 60,
      review: null,
    });

    const review = await createReviewForCompletedBooking({
      customerId: "cust_1",
      bookingId: "bk_1",
      rating: 5,
      comment: "Super",
    });

    expect(review.rating).toBe(5);
    expect(providerState.ratingAvg).toBe(4.5);
    expect(providerState.ratingCount).toBe(2);
  });

  it("rejects non-COMPLETED bookings", async () => {
    store.bookings.push({
      id: "bk_1",
      customerId: "cust_1",
      providerId: "prov_1",
      serviceId: "svc_1",
      status: "PENDING",
      scheduledAt: new Date(),
      durationMin: 60,
      review: null,
    });

    await expect(
      createReviewForCompletedBooking({
        customerId: "cust_1",
        bookingId: "bk_1",
        rating: 5,
      }),
    ).rejects.toBeInstanceOf(ReviewNotAllowedError);
  });

  it("rejects duplicate reviews", async () => {
    store.bookings.push({
      id: "bk_1",
      customerId: "cust_1",
      providerId: "prov_1",
      serviceId: "svc_1",
      status: "COMPLETED",
      scheduledAt: new Date(),
      durationMin: 60,
      review: { id: "rv_existing" },
    });

    await expect(
      createReviewForCompletedBooking({
        customerId: "cust_1",
        bookingId: "bk_1",
        rating: 4,
      }),
    ).rejects.toThrow(/už má recenziu/);
  });

  it("rejects missing booking", async () => {
    await expect(
      createReviewForCompletedBooking({
        customerId: "cust_1",
        bookingId: "missing",
        rating: 4,
      }),
    ).rejects.toThrow(/nenašla/);
  });
});
