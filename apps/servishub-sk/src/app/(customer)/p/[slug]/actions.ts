"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { getSessionProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import {
  BookingConflictError,
  createBookingWithConflictCheck,
  isSerializationFailure,
  listProviderBookedRanges,
} from "@/lib/data/bookings";
import { listActiveAvailability } from "@/lib/data/availability";
import { prisma } from "@/lib/prisma";
import { safeDb } from "@/lib/data/db";
import { bookingSchema } from "@/lib/validation/booking";
import {
  generateDaySlots,
  todayInZone,
  zonedTimeToUtc,
  type Slot,
} from "@/lib/booking/slots";
import { sendBookingConfirmationEmail } from "@/lib/notifications/email";

const DEFAULT_DURATION_MIN = 60;
/** Slots can be booked at most this many days ahead. */
const MAX_BOOKING_HORIZON_DAYS = 60;
/** Minimum lead time so providers are not surprised by instant bookings. */
const MIN_LEAD_MIN = 60;

export type SerializedSlot = {
  startTime: string;
  endTime: string;
  isAvailable: boolean;
};

function nextDateString(date: string): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}

type BookableService = {
  id: string;
  providerId: string;
  durationMin: number | null;
  priceFrom: { toString(): string } | null;
  title: string;
};

async function getBookableService(
  providerId: string,
  serviceId: string,
): Promise<BookableService | null> {
  return safeDb(async () => {
    const service = await prisma.service.findFirst({
      where: { id: serviceId, providerId, isActive: true },
      select: {
        id: true,
        providerId: true,
        durationMin: true,
        priceFrom: true,
        title: true,
      },
    });
    return service;
  }, null);
}

async function computeSlotsForDay(
  providerId: string,
  durationMin: number,
  date: string,
): Promise<Slot[]> {
  const windows = (await listActiveAvailability(providerId)).map((window) => ({
    dayOfWeek: window.dayOfWeek,
    startTime: window.startTime,
    endTime: window.endTime,
  }));
  if (windows.length === 0) return [];

  const dayStartUtc = zonedTimeToUtc(date, "00:00");
  const dayEndUtc = zonedTimeToUtc(nextDateString(date), "00:00");
  const booked = await listProviderBookedRanges(providerId, dayStartUtc, dayEndUtc);

  return generateDaySlots({
    date,
    windows,
    durationMin,
    booked,
    minLeadMin: MIN_LEAD_MIN,
  });
}

/**
 * Public slot listing for the booking picker. Returns only labels and
 * availability — absolute instants are recomputed server-side on submit.
 */
export async function getAvailableSlots(
  providerId: string,
  serviceId: string,
  date: string,
): Promise<SerializedSlot[]> {
  if (!isDatabaseConfigured()) return [];

  const service = await getBookableService(providerId, serviceId);
  if (!service) return [];

  const slots = await computeSlotsForDay(
    providerId,
    service.durationMin ?? DEFAULT_DURATION_MIN,
    date,
  );

  return slots.map((slot) => ({
    startTime: slot.startTime,
    endTime: slot.endTime,
    isAvailable: slot.isAvailable,
  }));
}

export type BookingFormState = {
  status: "idle" | "success" | "error";
  code?: "UNAUTHENTICATED" | "CONFLICT";
  message?: string;
  fieldErrors?: Record<string, string[] | undefined>;
  summary?: {
    serviceTitle: string;
    date: string;
    timeRange: string;
    providerName: string;
  };
};

export async function createBooking(
  _prevState: BookingFormState,
  formData: FormData,
): Promise<BookingFormState> {
  if (!isDatabaseConfigured()) {
    return {
      status: "error",
      message:
        "Rezervácie budú dostupné po napojení databázy. Skúste to neskôr.",
    };
  }

  const profile = await getSessionProfile();
  if (!profile) {
    return {
      status: "error",
      code: "UNAUTHENTICATED",
      message: "Pre rezerváciu termínu sa prihláste alebo zaregistrujte.",
    };
  }

  const providerId = formData.get("providerId")?.toString() ?? "";
  const slug = formData.get("slug")?.toString() ?? "";

  const parsed = bookingSchema.safeParse({
    serviceId: formData.get("serviceId"),
    date: formData.get("date"),
    startTime: formData.get("startTime"),
    addressLine: formData.get("addressLine"),
    city: formData.get("city"),
    postalCode: formData.get("postalCode"),
    notes: formData.get("notes"),
  });

  if (!parsed.success) {
    return {
      status: "error",
      message: "Skontrolujte vyznačené polia formulára.",
      fieldErrors: z.flattenError(parsed.error).fieldErrors,
    };
  }

  const input = parsed.data;

  // Date must be today or later (in the booking timezone) and within horizon.
  const todayStart = zonedTimeToUtc(todayInZone(), "00:00");
  const requestedStart = zonedTimeToUtc(input.date, "00:00");
  const horizonEnd = new Date(
    todayStart.getTime() + (MAX_BOOKING_HORIZON_DAYS + 1) * 24 * 3600000,
  );
  if (requestedStart < todayStart || requestedStart >= horizonEnd) {
    return {
      status: "error",
      message: "Zvolený dátum nie je možné rezervovať.",
      fieldErrors: { date: ["Vyberte dátum v najbližších 60 dňoch"] },
    };
  }

  const provider = await safeDb(
    () =>
      prisma.provider.findFirst({
        where: { id: providerId, isActive: true },
        select: { id: true, businessName: true, slug: true },
      }),
    null,
  );
  if (!provider) {
    return { status: "error", message: "Profesionál sa nenašiel." };
  }

  const service = await getBookableService(provider.id, input.serviceId);
  if (!service) {
    return { status: "error", message: "Vybraná služba nie je dostupná." };
  }

  const durationMin = service.durationMin ?? DEFAULT_DURATION_MIN;

  // Recompute slots server-side — never trust the client that a slot is free.
  const slots = await computeSlotsForDay(provider.id, durationMin, input.date);
  const chosen = slots.find((slot) => slot.startTime === input.startTime);
  if (!chosen || !chosen.isAvailable) {
    return {
      status: "error",
      code: "CONFLICT",
      message:
        "Tento termín už nie je voľný. Vyberte prosím iný čas alebo dátum.",
    };
  }

  try {
    await createBookingWithConflictCheck({
      customerId: profile.id,
      providerId: provider.id,
      serviceId: service.id,
      start: chosen.start,
      durationMin,
      addressLine: input.addressLine,
      city: input.city,
      postalCode: input.postalCode,
      notes: input.notes,
      priceAmount: service.priceFrom ? Number(service.priceFrom) : null,
    });
  } catch (error) {
    if (error instanceof BookingConflictError || isSerializationFailure(error)) {
      return {
        status: "error",
        code: "CONFLICT",
        message:
          "Tento termín bol práve obsadený inou rezerváciou. Vyberte iný čas.",
      };
    }
    console.error("[booking] createBooking failed:", error);
    return {
      status: "error",
      message: "Rezerváciu sa nepodarilo vytvoriť. Skúste to znova.",
    };
  }

  await sendBookingConfirmationEmail({
    to: profile.email,
    customerName: profile.fullName,
    providerName: provider.businessName,
    serviceTitle: service.title,
    start: chosen.start,
    durationMin,
    priceAmount: service.priceFrom ? Number(service.priceFrom) : null,
  });

  revalidatePath(`/p/${slug || provider.slug}`);
  revalidatePath("/moje-rezervacie");

  return {
    status: "success",
    message: "Rezervácia bola vytvorená a čaká na potvrdenie profesionálom.",
    summary: {
      serviceTitle: service.title,
      date: input.date,
      timeRange: `${chosen.startTime} – ${chosen.endTime}`,
      providerName: provider.businessName,
    },
  };
}
