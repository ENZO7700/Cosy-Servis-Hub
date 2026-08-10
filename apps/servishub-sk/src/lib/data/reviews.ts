import { prisma } from "@/lib/prisma";

export class ReviewNotAllowedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ReviewNotAllowedError";
  }
}

/**
 * Creates a review for a COMPLETED booking owned by the customer and updates
 * provider ratingAvg / ratingCount in the same transaction.
 */
export async function createReviewForCompletedBooking(input: {
  customerId: string;
  bookingId: string;
  rating: number;
  comment?: string | null;
}) {
  return prisma.$transaction(async (tx) => {
    const booking = await tx.booking.findFirst({
      where: {
        id: input.bookingId,
        customerId: input.customerId,
      },
      include: { review: true },
    });

    if (!booking) {
      throw new ReviewNotAllowedError("Rezervácia sa nenašla.");
    }
    if (booking.status !== "COMPLETED") {
      throw new ReviewNotAllowedError(
        "Recenziu môžete pridať až po dokončení služby.",
      );
    }
    if (booking.review) {
      throw new ReviewNotAllowedError("Táto rezervácia už má recenziu.");
    }

    const review = await tx.review.create({
      data: {
        bookingId: booking.id,
        customerId: input.customerId,
        providerId: booking.providerId,
        rating: input.rating,
        comment: input.comment || null,
      },
    });

    const provider = await tx.provider.findUniqueOrThrow({
      where: { id: booking.providerId },
      select: { ratingAvg: true, ratingCount: true },
    });

    const nextCount = provider.ratingCount + 1;
    const nextAvg =
      (provider.ratingAvg * provider.ratingCount + input.rating) / nextCount;

    await tx.provider.update({
      where: { id: booking.providerId },
      data: {
        ratingAvg: Math.round(nextAvg * 100) / 100,
        ratingCount: nextCount,
      },
    });

    return review;
  });
}
