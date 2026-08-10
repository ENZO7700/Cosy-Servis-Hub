"use server";

import { z } from "zod";
import { isDatabaseConfigured } from "@/lib/data/db";
import { prisma } from "@/lib/prisma";

export type WaitlistFormState = {
  status: "idle" | "success" | "error";
  message?: string;
};

const waitlistSchema = z.object({
  email: z.string().trim().email("Zadajte platný email"),
  city: z
    .string()
    .trim()
    .max(60)
    .optional()
    .or(z.literal("")),
  promoCode: z
    .string()
    .trim()
    .max(40)
    .optional()
    .or(z.literal("")),
});

export async function joinWaitlist(
  _prev: WaitlistFormState,
  formData: FormData,
): Promise<WaitlistFormState> {
  if (!isDatabaseConfigured()) {
    return {
      status: "error",
      message:
        "Waitlist zatiaľ nie je dostupný — chýba DATABASE_URL. Skúste to neskôr.",
    };
  }

  const parsed = waitlistSchema.safeParse({
    email: formData.get("email"),
    city: formData.get("city"),
    promoCode: formData.get("promoCode"),
  });

  if (!parsed.success) {
    return {
      status: "error",
      message: parsed.error.issues[0]?.message ?? "Neplatný email.",
    };
  }

  const { email, city, promoCode } = parsed.data;
  const noteParts = [
    "Waitlist signup",
    promoCode ? `promo=${promoCode}` : null,
  ].filter(Boolean);

  try {
    await prisma.lead.create({
      data: {
        status: "NEW",
        source: "waitlist",
        city: city || "Bratislava",
        contactEmail: email,
        contactName: null,
        message: noteParts.join(" · "),
      },
    });
  } catch (error) {
    console.error("[waitlist] lead create failed:", error);
    return {
      status: "error",
      message: "Nepodarilo sa uložiť email. Skúste to znova.",
    };
  }

  return {
    status: "success",
    message: "Ďakujeme! Dáme vám vedieť, keď spustíme ServisHub v Bratislave.",
  };
}
