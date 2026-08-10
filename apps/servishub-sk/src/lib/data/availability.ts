import type { Availability } from "@/generated/prisma/client";
import { prisma } from "@/lib/prisma";
import { safeDb } from "@/lib/data/db";
import type { AvailabilityWindowInput } from "@/lib/validation/availability";

/** All weekly availability windows of a provider, ordered by day/start. */
export async function listProviderAvailability(
  providerId: string,
): Promise<Availability[]> {
  return safeDb(
    () =>
      prisma.availability.findMany({
        where: { providerId },
        orderBy: [{ dayOfWeek: "asc" }, { startTime: "asc" }],
      }),
    [],
  );
}

/** Active windows only — used for public slot computation. */
export async function listActiveAvailability(
  providerId: string,
): Promise<Availability[]> {
  return safeDb(
    () =>
      prisma.availability.findMany({
        where: { providerId, isActive: true },
        orderBy: [{ dayOfWeek: "asc" }, { startTime: "asc" }],
      }),
    [],
  );
}

/**
 * Replaces the whole weekly availability of a provider atomically.
 * Throws on DB errors — authorize in the calling server action.
 */
export async function replaceProviderAvailability(
  providerId: string,
  windows: AvailabilityWindowInput[],
): Promise<void> {
  await prisma.$transaction(async (tx) => {
    await tx.availability.deleteMany({ where: { providerId } });
    if (windows.length > 0) {
      await tx.availability.createMany({
        data: windows.map((window) => ({
          providerId,
          dayOfWeek: window.dayOfWeek,
          startTime: window.startTime,
          endTime: window.endTime,
        })),
      });
    }
  });
}
