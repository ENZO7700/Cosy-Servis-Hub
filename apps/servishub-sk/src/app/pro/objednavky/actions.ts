"use server";

import { revalidatePath } from "next/cache";
import { requireProviderProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { getProviderByProfileId } from "@/lib/data/providers";
import { updateProviderBookingStatus } from "@/lib/data/provider-bookings";

export type ProviderBookingActionState = {
  status: "idle" | "success" | "error";
  message?: string;
};

const ALLOWED = ["CONFIRMED", "COMPLETED", "CANCELLED"] as const;

export async function updateBookingStatusAction(
  bookingId: string,
  status: string,
): Promise<ProviderBookingActionState> {
  if (!isDatabaseConfigured()) {
    return { status: "error", message: "Databáza nie je nakonfigurovaná." };
  }

  if (!ALLOWED.includes(status as (typeof ALLOWED)[number])) {
    return { status: "error", message: "Neplatný stav rezervácie." };
  }

  const profile = await requireProviderProfile();
  const provider = await getProviderByProfileId(profile.id);
  if (!provider) {
    return { status: "error", message: "Najprv vyplňte profil profesionála." };
  }

  try {
    const ok = await updateProviderBookingStatus(
      provider.id,
      bookingId,
      status as (typeof ALLOWED)[number],
    );
    if (!ok) {
      return { status: "error", message: "Rezervácia sa nenašla." };
    }
  } catch (error) {
    console.error("[pro/objednavky] update status failed:", error);
    return { status: "error", message: "Aktualizácia zlyhala." };
  }

  revalidatePath("/pro/objednavky");
  revalidatePath("/moje-rezervacie");
  return { status: "success", message: "Stav rezervácie bol aktualizovaný." };
}
