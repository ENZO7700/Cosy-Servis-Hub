import type { Booking, Service, Profile } from "@/generated/prisma/client";
import { prisma } from "@/lib/prisma";
import { safeDb } from "@/lib/data/db";

export type ProviderBooking = Booking & {
  service: Pick<Service, "id" | "title" | "durationMin"> | null;
  customer: Pick<Profile, "id" | "fullName" | "email" | "phone">;
};

/** Provider's bookings, upcoming first. */
export async function listProviderBookings(
  providerId: string,
): Promise<ProviderBooking[]> {
  return safeDb(
    () =>
      prisma.booking.findMany({
        where: { providerId },
        include: {
          service: { select: { id: true, title: true, durationMin: true } },
          customer: {
            select: { id: true, fullName: true, email: true, phone: true },
          },
        },
        orderBy: { scheduledAt: "desc" },
        take: 100,
      }),
    [],
  );
}

/** Marks a provider-owned booking as CONFIRMED / COMPLETED / CANCELLED. */
export async function updateProviderBookingStatus(
  providerId: string,
  bookingId: string,
  status: "CONFIRMED" | "COMPLETED" | "CANCELLED",
): Promise<boolean> {
  const result = await prisma.booking.updateMany({
    where: { id: bookingId, providerId },
    data: { status },
  });
  return result.count > 0;
}
