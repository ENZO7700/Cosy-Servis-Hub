import { beforeEach, describe, expect, it, vi } from "vitest";
import { Prisma } from "@/generated/prisma/client";
import { createTxBookingsStore } from "@/test/mocks/prisma";

const store = createTxBookingsStore();

vi.mock("@/lib/prisma", () => ({
  prisma: {
    $transaction: async (fn: (tx: typeof store) => Promise<unknown>) =>
      fn(store),
    booking: {
      findMany: (...args: unknown[]) =>
        (store.booking.findMany as (...a: unknown[]) => unknown)(...args),
      updateMany: (...args: unknown[]) =>
        (store.booking.updateMany as (...a: unknown[]) => unknown)(...args),
    },
  },
}));

import {
  BookingConflictError,
  cancelCustomerBooking,
  createBookingWithConflictCheck,
  isSerializationFailure,
} from "./bookings";

describe("createBookingWithConflictCheck", () => {
  beforeEach(() => {
    store.bookings.length = 0;
    process.env.DATABASE_URL = "postgresql://localhost/test";
  });

  it("creates a PENDING booking when the slot is free", async () => {
    const booking = await createBookingWithConflictCheck({
      customerId: "cust_1",
      providerId: "prov_1",
      serviceId: "svc_1",
      start: new Date("2026-08-10T08:00:00Z"),
      durationMin: 60,
    });
    expect(booking.status).toBe("PENDING");
    expect(booking.customerId).toBe("cust_1");
    expect(store.bookings).toHaveLength(1);
  });

  it("throws BookingConflictError on overlapping active booking", async () => {
    store.bookings.push({
      id: "existing",
      customerId: "other",
      providerId: "prov_1",
      serviceId: "svc_1",
      status: "CONFIRMED",
      scheduledAt: new Date("2026-08-10T08:00:00Z"),
      durationMin: 60,
    });

    await expect(
      createBookingWithConflictCheck({
        customerId: "cust_1",
        providerId: "prov_1",
        serviceId: "svc_1",
        start: new Date("2026-08-10T08:30:00Z"),
        durationMin: 60,
      }),
    ).rejects.toBeInstanceOf(BookingConflictError);
  });

  it("allows adjacent half-open ranges", async () => {
    store.bookings.push({
      id: "existing",
      customerId: "other",
      providerId: "prov_1",
      serviceId: "svc_1",
      status: "CONFIRMED",
      scheduledAt: new Date("2026-08-10T08:00:00Z"),
      durationMin: 60,
    });

    const booking = await createBookingWithConflictCheck({
      customerId: "cust_1",
      providerId: "prov_1",
      serviceId: "svc_1",
      start: new Date("2026-08-10T09:00:00Z"),
      durationMin: 60,
    });
    expect(booking.status).toBe("PENDING");
  });

  it("ignores CANCELLED bookings for conflicts", async () => {
    store.bookings.push({
      id: "cancelled",
      customerId: "other",
      providerId: "prov_1",
      serviceId: "svc_1",
      status: "CANCELLED",
      scheduledAt: new Date("2026-08-10T08:00:00Z"),
      durationMin: 60,
    });

    const booking = await createBookingWithConflictCheck({
      customerId: "cust_1",
      providerId: "prov_1",
      serviceId: "svc_1",
      start: new Date("2026-08-10T08:00:00Z"),
      durationMin: 60,
    });
    expect(booking.status).toBe("PENDING");
  });
});

describe("isSerializationFailure", () => {
  it("detects Prisma P2034", () => {
    const error = new Prisma.PrismaClientKnownRequestError("conflict", {
      code: "P2034",
      clientVersion: "test",
    });
    expect(isSerializationFailure(error)).toBe(true);
    expect(isSerializationFailure(new Error("nope"))).toBe(false);
  });
});

describe("cancelCustomerBooking", () => {
  beforeEach(() => {
    store.bookings.length = 0;
  });

  it("cancels own PENDING booking", async () => {
    store.bookings.push({
      id: "bk_1",
      customerId: "cust_1",
      providerId: "prov_1",
      serviceId: "svc_1",
      status: "PENDING",
      scheduledAt: new Date(),
      durationMin: 60,
    });
    await expect(cancelCustomerBooking("cust_1", "bk_1")).resolves.toBe(true);
    expect(store.bookings[0]?.status).toBe("CANCELLED");
  });

  it("returns false for wrong owner or COMPLETED", async () => {
    store.bookings.push({
      id: "bk_1",
      customerId: "cust_1",
      providerId: "prov_1",
      serviceId: "svc_1",
      status: "COMPLETED",
      scheduledAt: new Date(),
      durationMin: 60,
    });
    await expect(cancelCustomerBooking("cust_1", "bk_1")).resolves.toBe(false);
    await expect(cancelCustomerBooking("other", "bk_1")).resolves.toBe(false);
  });
});
