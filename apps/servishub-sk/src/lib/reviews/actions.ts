"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { getSessionProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { createReviewForCompletedBooking } from "@/lib/data/reviews";

export type ReviewFormState = {
  status: "idle" | "success" | "error";
  message?: string;
};

const reviewSchema = z.object({
  bookingId: z.string().min(1),
  providerSlug: z.string().optional(),
  rating: z.coerce.number().int().min(1).max(5),
  comment: z
    .string()
    .trim()
    .max(1000)
    .optional()
    .or(z.literal("")),
});

export async function submitReview(
  _prev: ReviewFormState,
  formData: FormData,
): Promise<ReviewFormState> {
  if (!isDatabaseConfigured()) {
    return {
      status: "error",
      message: "Recenzie budú dostupné po napojení databázy.",
    };
  }

  const profile = await getSessionProfile();
  if (!profile) {
    return { status: "error", message: "Pre odoslanie recenzie sa prihláste." };
  }

  const parsed = reviewSchema.safeParse({
    bookingId: formData.get("bookingId"),
    providerSlug: formData.get("providerSlug"),
    rating: formData.get("rating"),
    comment: formData.get("comment"),
  });

  if (!parsed.success) {
    return { status: "error", message: "Skontrolujte hodnotenie (1–5)." };
  }

  try {
    await createReviewForCompletedBooking({
      customerId: profile.id,
      bookingId: parsed.data.bookingId,
      rating: parsed.data.rating,
      comment: parsed.data.comment || null,
    });
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : "Recenziu sa nepodarilo uložiť.";
    return { status: "error", message };
  }

  revalidatePath("/moje-rezervacie");
  if (parsed.data.providerSlug) {
    revalidatePath(`/p/${parsed.data.providerSlug}`);
    revalidatePath(`/p/${parsed.data.providerSlug}/recenzia`);
  }

  return { status: "success", message: "Recenzia bola uložená. Ďakujeme!" };
}
