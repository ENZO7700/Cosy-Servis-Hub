import {
  Prisma,
  type Booking,
  type Provider,
  type Service,
} from "@/generated/prisma/client";
import { prisma } from "@/lib/prisma";
import { safeDb } from "@/lib/data/db";
import type { BookedRange } from "@/lib/booking/slots";
import { rangesOverlap } from "@/lib/booking/slots";

/**
 * Statuses that block a time slot. Mirrors the partial constraint
 * `WHERE status != 'cancelled'` from the mistral 009 concurrency hardening
 * (adapted for this schema in supabase/migrations).
 */
export const ACTIVE_BOOKING_STATUSES = [
  "PENDING",
  "CONFIRMED",
  "IN_PROGRESS",
] as const;

export class BookingConflictError extends Error {
  constructor() {
    super("Time slot already booked");
    this.name = "BookingConflictError";
  }
}

function toBookedRange(booking: {
  scheduledAt: Date;
  durationMin: number | null;
}): BookedRange {
  const duration = booking.durationMin ?? 60;
  return {
    start: booking.scheduledAt,
    end: new Date(booking.scheduledAt.getTime() + duration * 60000),
  };
}

/**
 * Booked ranges for a provider on one day (UTC-bounded query, JS-refined).
 * Used to mark unavailable slots in the picker.
 */
export async function listProviderBookedRanges(
  providerId: string,
  dayStartUtc: Date,
  dayEndUtc: Date,
): Promise<BookedRange[]> {
  return safeDb(async () => {
    const bookings = await prisma.booking.findMany({
      where: {
        providerId,
        status: { in: [...ACTIVE_BOOKING_STATUSES] },
        // Wide bound: any booking that could spill into the day.
        scheduledAt: {
          gte: new Date(dayStartUtc.getTime() - 24 * 3600000),
          lt: dayEndUtc,
        },
      },
      select: { scheduledAt: true, durationMin: true },
    });
    return bookings
      .map(toBookedRange)
      .filter((range) =>
        rangesOverlap(range.start, range.end, dayStartUtc, dayEndUtc),
      );
  }, []);
}

export type CreateBookingInput = {
  customerId: string;
  providerId: string;
  serviceId: string;
  start: Date;
  durationMin: number;
  addressLine?: string;
  city?: string;
  postalCode?: string;
  notes?: string;
  priceAmount?: number | null;
};

/**
 * Creates a PENDING booking with double-booking protection.
 *
 * The overlap re-check runs inside a SERIALIZABLE transaction: two concurrent
 * attempts to book overlapping ranges read a conflicting predicate, so one of
 * them aborts (Prisma P2034 / Postgres 40001) instead of silently inserting.
 * This is the app-level equivalent of the EXCLUDE constraint from mistral's
 * 009 migration; the same constraint is prepared for the DB in
 * supabase/migrations for defence in depth once a live DB is linked.
 *
 * Throws BookingConflictError when the slot is taken, Prisma error otherwise.
 */
export async function createBookingWithConflictCheck(
  input: CreateBookingInput,
): Promise<Booking> {
  const end = new Date(input.start.getTime() + input.durationMin * 60000);

  return prisma.$transaction(
    async (tx) => {
      const candidates = await tx.booking.findMany({
        where: {
          providerId: input.providerId,
          status: { in: [...ACTIVE_BOOKING_STATUSES] },
          scheduledAt: {
            gte: new Date(input.start.getTime() - 24 * 3600000),
            lt: end,
          },
        },
        select: { scheduledAt: true, durationMin: true },
      });

      const conflict = candidates
        .map(toBookedRange)
        .some((range) =>
          rangesOverlap(input.start, end, range.start, range.end),
        );
      if (conflict) {
        throw new BookingConflictError();
      }

      return tx.booking.create({
        data: {
          customerId: input.customerId,
          providerId: input.providerId,
          serviceId: input.serviceId,
          status: "PENDING",
          scheduledAt: input.start,
          durationMin: input.durationMin,
          addressLine: input.addressLine || null,
          city: input.city || null,
          postalCode: input.postalCode || null,
          notes: input.notes || null,
          priceAmount: input.priceAmount ?? null,
          currency: "EUR",
        },
      });
    },
    { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
  );
}

/** True for transaction-abort errors caused by serialization conflicts. */
export function isSerializationFailure(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === "P2034"
  );
}

export type CustomerBooking = Booking & {
  service: Pick<Service, "id" | "title" | "durationMin"> | null;
  provider: Pick<Provider, "id" | "businessName" | "slug" | "city">;
};

/** Customer's bookings, newest first. */
export async function listCustomerBookings(
  customerId: string,
): Promise<CustomerBooking[]> {
  return safeDb(
    () =>
      prisma.booking.findMany({
        where: { customerId },
        include: {
          service: { select: { id: true, title: true, durationMin: true } },
          provider: {
            select: { id: true, businessName: true, slug: true, city: true },
          },
        },
        orderBy: { scheduledAt: "desc" },
      }),
    [],
  );
}

/**
 * Cancels a booking owned by the customer.
 * Only PENDING/CONFIRMED can be cancelled (provider workflow handles the rest).
 * Returns false when the booking does not exist, belongs to someone else, or
 * is in a non-cancellable state.
 */
export async function cancelCustomerBooking(
  customerId: string,
  bookingId: string,
): Promise<boolean> {
  const result = await prisma.booking.updateMany({
    where: {
      id: bookingId,
      customerId,
      status: { in: ["PENDING", "CONFIRMED"] },
    },
    data: { status: "CANCELLED" },
  });
  return result.count > 0;
}

/** Booking with relations for confirmation emails / detail views. */
export async function getBookingForCustomer(
  customerId: string,
  bookingId: string,
): Promise<CustomerBooking | null> {
  return safeDb(
    () =>
      prisma.booking.findFirst({
        where: { id: bookingId, customerId },
        include: {
          service: { select: { id: true, title: true, durationMin: true } },
          provider: {
            select: { id: true, businessName: true, slug: true, city: true },
          },
        },
      }),
    null,
  );
}
