"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { requireProviderProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { getProviderByProfileId } from "@/lib/data/providers";
import { replaceProviderAvailability } from "@/lib/data/availability";
import {
  availabilityFormSchema,
  type AvailabilityWindowInput,
} from "@/lib/validation/availability";

export type AvailabilityFormState = {
  status: "idle" | "success" | "error";
  message?: string;
};

const DAY_COUNT = 7;

/**
 * Saves the weekly availability grid. The form submits one row per weekday:
 * `day-{0..6}-enabled`, `day-{0..6}-start`, `day-{0..6}-end` (HH:mm).
 * Disabled rows are ignored; enabled rows must have start < end and must not
 * overlap another window on the same day.
 */
export async function saveAvailability(
  _prevState: AvailabilityFormState,
  formData: FormData,
): Promise<AvailabilityFormState> {
  if (!isDatabaseConfigured()) {
    return {
      status: "error",
      message:
        "Databáza zatiaľ nie je nakonfigurovaná (chýba DATABASE_URL). Dostupnosť sa nedá uložiť.",
    };
  }

  const profile = await requireProviderProfile();
  const provider = await getProviderByProfileId(profile.id);
  if (!provider) {
    return {
      status: "error",
      message: "Najprv vyplňte profil profesionála na stránke /pro/profil.",
    };
  }

  const windows: AvailabilityWindowInput[] = [];
  for (let day = 0; day < DAY_COUNT; day += 1) {
    if (formData.get(`day-${day}-enabled`) !== "on") continue;
    windows.push({
      dayOfWeek: day,
      startTime: formData.get(`day-${day}-start`)?.toString() ?? "",
      endTime: formData.get(`day-${day}-end`)?.toString() ?? "",
    });
  }

  const parsed = availabilityFormSchema.safeParse(windows);
  if (!parsed.success) {
    const firstIssue = parsed.error.issues[0];
    return {
      status: "error",
      message: firstIssue
        ? `${firstIssue.message}${issueDayLabel(formData, firstIssue)}`
        : "Skontrolujte zadané časové okná.",
    };
  }

  try {
    await replaceProviderAvailability(provider.id, parsed.data);
  } catch (error) {
    console.error("[pro/dostupnost] saveAvailability failed:", error);
    return {
      status: "error",
      message: "Uloženie dostupnosti zlyhalo. Skúste to znova.",
    };
  }

  revalidatePath("/pro/dostupnost");
  return {
    status: "success",
    message: "Dostupnosť bola uložená.",
  };
}

const DAY_NAMES = ["nedeľa", "pondelok", "utorok", "streda", "štvrtok", "piatok", "sobota"];

/** Appends the day name to validation issues so the provider finds the row. */
function issueDayLabel(formData: FormData, issue: z.core.$ZodIssue): string {
  const index = Number(issue.path[0]);
  if (!Number.isInteger(index)) return "";
  // Re-derive the day of the failing window from the submitted form order.
  const enabledDays: number[] = [];
  for (let day = 0; day < DAY_COUNT; day += 1) {
    if (formData.get(`day-${day}-enabled`) === "on") enabledDays.push(day);
  }
  const day = enabledDays[index];
  return day === undefined ? "" : ` (${DAY_NAMES[day]})`;
}
