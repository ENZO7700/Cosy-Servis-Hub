import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("next/cache", () => ({
  revalidatePath: vi.fn(),
}));

const getSessionProfile = vi.fn();
const createBookingWithConflictCheck = vi.fn();
const listActiveAvailability = vi.fn();
const listProviderBookedRanges = vi.fn();
const sendBookingConfirmationEmail = vi.fn();
const serviceFindFirst = vi.fn();
const providerFindFirst = vi.fn();

vi.mock("@/lib/auth/session", () => ({
  getSessionProfile: (...args: unknown[]) => getSessionProfile(...args),
}));

vi.mock("@/lib/data/db", () => ({
  isDatabaseConfigured: () => true,
  safeDb: async <T>(query: () => Promise<T>): Promise<T> => query(),
}));

vi.mock("@/lib/data/bookings", () => {
  class BookingConflictError extends Error {
    constructor() {
      super("Time slot already booked");
      this.name = "BookingConflictError";
    }
  }
  return {
    BookingConflictError,
    createBookingWithConflictCheck: (...args: unknown[]) =>
      createBookingWithConflictCheck(...args),
    isSerializationFailure: () => false,
    listProviderBookedRanges: (...args: unknown[]) =>
      listProviderBookedRanges(...args),
  };
});

vi.mock("@/lib/data/availability", () => ({
  listActiveAvailability: (...args: unknown[]) =>
    listActiveAvailability(...args),
}));

vi.mock("@/lib/notifications/email", () => ({
  sendBookingConfirmationEmail: (...args: unknown[]) =>
    sendBookingConfirmationEmail(...args),
}));

vi.mock("@/lib/prisma", () => ({
  prisma: {
    service: {
      findFirst: (...args: unknown[]) => serviceFindFirst(...args),
    },
    provider: {
      findFirst: (...args: unknown[]) => providerFindFirst(...args),
    },
  },
}));

vi.mock("@/lib/booking/slots", async () => {
  const actual = await vi.importActual<typeof import("@/lib/booking/slots")>(
    "@/lib/booking/slots",
  );
  return {
    ...actual,
    todayInZone: () => "2026-08-10",
  };
});

import { BookingConflictError } from "@/lib/data/bookings";
import { createBooking } from "./actions";
import { zonedTimeToUtc } from "@/lib/booking/slots";

/** FormData.get returns null for missing keys — schema rejects null optionals. */
function form(data: Record<string, string>) {
  const fd = new FormData();
  const defaults = {
    addressLine: "",
    city: "",
    postalCode: "",
    notes: "",
  };
  for (const [k, v] of Object.entries({ ...defaults, ...data })) {
    fd.set(k, v);
  }
  return fd;
}

describe("createBooking action", () => {
  beforeEach(() => {
    // Keep booking-slot tests deterministic. Without a frozen clock,
    // fixed fixture dates eventually become past dates and the success
    // case starts failing even though production booking logic is correct.
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-08-10T08:00:00.000Z"));

    getSessionProfile.mockReset();
    createBookingWithConflictCheck.mockReset();
    listActiveAvailability.mockReset();
    listProviderBookedRanges.mockReset();
    sendBookingConfirmationEmail.mockReset();
    serviceFindFirst.mockReset();
    providerFindFirst.mockReset();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("returns UNAUTHENTICATED without session", async () => {
    getSessionProfile.mockResolvedValue(null);
    const result = await createBooking(
      { status: "idle" },
      form({
        providerId: "p1",
        serviceId: "s1",
        date: "2026-08-11",
        startTime: "10:00",
      }),
    );
    expect(result.code).toBe("UNAUTHENTICATED");
  });

  it("returns fieldErrors for invalid payload", async () => {
    getSessionProfile.mockResolvedValue({ id: "cust", email: "a@b.sk" });
    const result = await createBooking(
      { status: "idle" },
      form({
        providerId: "p1",
        serviceId: "",
        date: "bad",
        startTime: "9:00",
      }),
    );
    expect(result.status).toBe("error");
    expect(result.fieldErrors).toBeDefined();
  });

  it("rejects dates outside horizon", async () => {
    getSessionProfile.mockResolvedValue({ id: "cust", email: "a@b.sk" });
    const result = await createBooking(
      { status: "idle" },
      form({
        providerId: "p1",
        serviceId: "s1",
        date: "2027-01-01",
        startTime: "10:00",
      }),
    );
    expect(result.status).toBe("error");
    expect(result.message).toMatch(/dátum/i);
    expect(result.fieldErrors?.date).toBeDefined();
  });

  it("returns CONFLICT when slot unavailable", async () => {
    getSessionProfile.mockResolvedValue({
      id: "cust",
      email: "a@b.sk",
      fullName: "Jan",
    });
    providerFindFirst.mockResolvedValue({
      id: "p1",
      businessName: "Firma",
      slug: "firma",
    });
    serviceFindFirst.mockResolvedValue({
      id: "s1",
      providerId: "p1",
      durationMin: 60,
      priceFrom: 40,
      title: "Upratovanie",
    });
    // 2026-08-11 is Tuesday (2)
    listActiveAvailability.mockResolvedValue([
      { dayOfWeek: 2, startTime: "09:00", endTime: "12:00" },
    ]);
    listProviderBookedRanges.mockResolvedValue([
      {
        start: zonedTimeToUtc("2026-08-11", "10:00"),
        end: zonedTimeToUtc("2026-08-11", "11:00"),
      },
    ]);

    const result = await createBooking(
      { status: "idle" },
      form({
        providerId: "p1",
        slug: "firma",
        serviceId: "s1",
        date: "2026-08-11",
        startTime: "10:00",
      }),
    );
    expect(result.code).toBe("CONFLICT");
  });

  it("creates booking and sends confirmation email", async () => {
    getSessionProfile.mockResolvedValue({
      id: "cust",
      email: "a@b.sk",
      fullName: "Jan",
    });
    providerFindFirst.mockResolvedValue({
      id: "p1",
      businessName: "Firma",
      slug: "firma",
    });
    serviceFindFirst.mockResolvedValue({
      id: "s1",
      providerId: "p1",
      durationMin: 60,
      priceFrom: 40,
      title: "Upratovanie",
    });
    listActiveAvailability.mockResolvedValue([
      { dayOfWeek: 2, startTime: "09:00", endTime: "12:00" },
    ]);
    listProviderBookedRanges.mockResolvedValue([]);
    createBookingWithConflictCheck.mockResolvedValue({ id: "bk_1" });
    sendBookingConfirmationEmail.mockResolvedValue({ delivered: false });

    const result = await createBooking(
      { status: "idle" },
      form({
        providerId: "p1",
        slug: "firma",
        serviceId: "s1",
        date: "2026-08-11",
        startTime: "10:00",
      }),
    );
    expect(result).toMatchObject({ status: "success" });
    expect(createBookingWithConflictCheck).toHaveBeenCalled();
    expect(sendBookingConfirmationEmail).toHaveBeenCalled();
  });

  it("maps BookingConflictError to CONFLICT", async () => {
    getSessionProfile.mockResolvedValue({
      id: "cust",
      email: "a@b.sk",
      fullName: "Jan",
    });
    providerFindFirst.mockResolvedValue({
      id: "p1",
      businessName: "Firma",
      slug: "firma",
    });
    serviceFindFirst.mockResolvedValue({
      id: "s1",
      providerId: "p1",
      durationMin: 60,
      priceFrom: 40,
      title: "Upratovanie",
    });
    listActiveAvailability.mockResolvedValue([
      { dayOfWeek: 2, startTime: "09:00", endTime: "12:00" },
    ]);
    listProviderBookedRanges.mockResolvedValue([]);
    createBookingWithConflictCheck.mockRejectedValue(new BookingConflictError());

    const result = await createBooking(
      { status: "idle" },
      form({
        providerId: "p1",
        slug: "firma",
        serviceId: "s1",
        date: "2026-08-11",
        startTime: "09:00",
      }),
    );
    expect(result.code).toBe("CONFLICT");
  });
});
