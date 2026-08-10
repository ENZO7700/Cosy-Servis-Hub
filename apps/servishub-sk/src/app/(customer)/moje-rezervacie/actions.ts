"use server";

import { revalidatePath } from "next/cache";
import { getSessionProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { cancelCustomerBooking } from "@/lib/data/bookings";

export type CancelBookingState = {
  status: "idle" | "success" | "error";
  message?: string;
};

export async function cancelBooking(
  bookingId: string,
): Promise<CancelBookingState> {
  if (!isDatabaseConfigured()) {
    return {
      status: "error",
      message: "Databáza zatiaľ nie je nakonfigurovaná.",
    };
  }

  const profile = await getSessionProfile();
  if (!profile) {
    return {
      status: "error",
      message: "Pre zrušenie rezervácie sa prihláste.",
    };
  }

  try {
    const cancelled = await cancelCustomerBooking(profile.id, bookingId);
    if (!cancelled) {
      return {
        status: "error",
        message:
          "Rezerváciu sa nepodarilo zrušiť — je už potvrdená v neskoršom stave alebo neexistuje.",
      };
    }
  } catch (error) {
    console.error("[moje-rezervacie] cancelBooking failed:", error);
    return {
      status: "error",
      message: "Zrušenie rezervácie zlyhalo. Skúste to znova.",
    };
  }

  revalidatePath("/moje-rezervacie");
  return { status: "success", message: "Rezervácia bola zrušená." };
}
