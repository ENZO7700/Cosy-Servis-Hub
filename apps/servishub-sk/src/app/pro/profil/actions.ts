"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { requireProviderProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { upsertProviderProfile } from "@/lib/data/providers";
import { providerProfileSchema } from "@/lib/validation/provider";

export type ProviderFormState = {
  status: "idle" | "success" | "error";
  message?: string;
  fieldErrors?: Record<string, string[] | undefined>;
};

export async function saveProviderProfile(
  _prevState: ProviderFormState,
  formData: FormData,
): Promise<ProviderFormState> {
  if (!isDatabaseConfigured()) {
    return {
      status: "error",
      message:
        "Databáza zatiaľ nie je nakonfigurovaná (chýba DATABASE_URL). Profil sa nedá uložiť.",
    };
  }

  // Redirects to /login?next=/pro when unauthenticated, to / when not PROVIDER/ADMIN.
  const profile = await requireProviderProfile();

  const parsed = providerProfileSchema.safeParse({
    businessName: formData.get("businessName"),
    businessType: formData.get("businessType"),
    bio: formData.get("bio"),
    ico: formData.get("ico"),
    dic: formData.get("dic"),
    city: formData.get("city"),
    postalCode: formData.get("postalCode"),
    categoryIds: formData.getAll("categoryIds"),
  });

  if (!parsed.success) {
    return {
      status: "error",
      message: "Skontrolujte vyznačené polia formulára.",
      fieldErrors: z.flattenError(parsed.error).fieldErrors,
    };
  }

  try {
    await upsertProviderProfile(profile.id, parsed.data);
  } catch (error) {
    console.error("[pro/profil] upsertProviderProfile failed:", error);
    return {
      status: "error",
      message: "Uloženie profilu zlyhalo. Skúste to znova.",
    };
  }

  revalidatePath("/pro/profil");
  revalidatePath("/hladat");
  return { status: "success", message: "Profil profesionála bol uložený." };
}
