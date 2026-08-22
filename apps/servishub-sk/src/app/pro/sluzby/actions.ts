"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireProviderProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { getProviderByProfileId } from "@/lib/data/providers";
import {
  createService,
  deactivateService,
  updateService,
} from "@/lib/data/services";
import { serviceSchema } from "@/lib/validation/service";

export type ServiceFormState = {
  status: "idle" | "error";
  message?: string;
  fieldErrors?: Record<string, string[] | undefined>;
};

export async function saveService(
  _prevState: ServiceFormState,
  formData: FormData,
): Promise<ServiceFormState> {
  if (!isDatabaseConfigured()) {
    return {
      status: "error",
      message:
        "Databáza zatiaľ nie je nakonfigurovaná (chýba DATABASE_URL). Služba sa nedá uložiť.",
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

  const serviceId = formData.get("serviceId")?.toString() || null;

  const parsed = serviceSchema.safeParse({
    title: formData.get("title"),
    description: formData.get("description"),
    categoryId: formData.get("categoryId"),
    priceFrom: formData.get("priceFrom"),
    priceTo: formData.get("priceTo"),
    durationMin: formData.get("durationMin"),
    isActive: formData.get("isActive") === "on",
  });

  if (!parsed.success) {
    return {
      status: "error",
      message: "Skontrolujte vyznačené polia formulára.",
      fieldErrors: z.flattenError(parsed.error).fieldErrors,
    };
  }

  try {
    if (serviceId) {
      const updated = await updateService(provider.id, serviceId, parsed.data);
      if (!updated) {
        return { status: "error", message: "Služba sa nenašla." };
      }
    } else {
      await createService(provider.id, parsed.data);
    }
  } catch (error) {
    console.error("[pro/sluzby] saveService failed:", error);
    return {
      status: "error",
      message: "Uloženie služby zlyhalo. Skúste to znova.",
    };
  }

  revalidatePath("/pro/sluzby");
  revalidatePath("/hladat");
  redirect("/pro/sluzby");
}

export async function deactivateServiceAction(serviceId: string): Promise<void> {
  if (!isDatabaseConfigured()) return;

  const profile = await requireProviderProfile();
  const provider = await getProviderByProfileId(profile.id);
  if (!provider) return;

  try {
    await deactivateService(provider.id, serviceId);
  } catch (error) {
    console.error("[pro/sluzby] deactivateService failed:", error);
  }

  revalidatePath("/pro/sluzby");
  revalidatePath("/hladat");
}
