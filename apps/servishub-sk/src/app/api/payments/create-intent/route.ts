import { NextResponse } from "next/server";
import { z } from "zod";
import { getSessionProfile } from "@/lib/auth/session";
import { isDatabaseConfigured, safeDb } from "@/lib/data/db";
import { prisma } from "@/lib/prisma";
import {
  applicationFeeAmountCents,
  getStripe,
} from "@/lib/stripe/client";

const bodySchema = z.object({
  bookingId: z.string().min(1),
});

/**
 * Creates a PaymentIntent for a customer-owned booking with Connect
 * application_fee_amount. Requires provider stripeAccountId.
 */
export async function POST(request: Request) {
  if (!isDatabaseConfigured()) {
    return NextResponse.json(
      { error: "Databáza nie je nakonfigurovaná." },
      { status: 503 },
    );
  }

  const profile = await getSessionProfile();
  if (!profile) {
    return NextResponse.json({ error: "Neautorizované." }, { status: 401 });
  }

  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return NextResponse.json({ error: "Neplatné JSON telo." }, { status: 400 });
  }

  const parsed = bodySchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: "Chýba bookingId." }, { status: 400 });
  }

  const booking = await safeDb(
    () =>
      prisma.booking.findFirst({
        where: { id: parsed.data.bookingId, customerId: profile.id },
        include: {
          provider: { select: { id: true, stripeAccountId: true, businessName: true } },
          payment: true,
        },
      }),
    null,
  );

  if (!booking) {
    return NextResponse.json({ error: "Rezervácia sa nenašla." }, { status: 404 });
  }

  if (booking.status === "CANCELLED") {
    return NextResponse.json(
      { error: "Zrušenú rezerváciu nie je možné zaplatiť." },
      { status: 400 },
    );
  }

  if (!booking.provider.stripeAccountId) {
    return NextResponse.json(
      { error: "Profesionál ešte nemá prepojený Stripe Connect účet." },
      { status: 400 },
    );
  }

  const amountEur = booking.priceAmount ? Number(booking.priceAmount) : 0;
  if (!amountEur || amountEur <= 0) {
    return NextResponse.json(
      { error: "Rezervácia nemá cenu vhodnú na online platbu." },
      { status: 400 },
    );
  }

  const amountCents = Math.round(amountEur * 100);
  const feeCents = applicationFeeAmountCents(amountCents);

  try {
    const stripe = getStripe();

    if (booking.stripePaymentIntentId && booking.payment) {
      const existing = await stripe.paymentIntents.retrieve(
        booking.stripePaymentIntentId,
      );
      return NextResponse.json({
        clientSecret: existing.client_secret,
        paymentIntentId: existing.id,
        applicationFeeAmount: feeCents,
      });
    }

    const intent = await stripe.paymentIntents.create({
      amount: amountCents,
      currency: (booking.currency || "eur").toLowerCase(),
      automatic_payment_methods: { enabled: true },
      application_fee_amount: feeCents,
      transfer_data: {
        destination: booking.provider.stripeAccountId,
      },
      metadata: {
        bookingId: booking.id,
        providerId: booking.providerId,
        customerId: booking.customerId,
      },
    });

    await prisma.$transaction([
      prisma.booking.update({
        where: { id: booking.id },
        data: { stripePaymentIntentId: intent.id },
      }),
      prisma.payment.upsert({
        where: { bookingId: booking.id },
        create: {
          bookingId: booking.id,
          intentId: intent.id,
          amount: amountEur,
          applicationFee: feeCents / 100,
          currency: booking.currency || "EUR",
          status: "REQUIRES_PAYMENT_METHOD",
          captureMethod: "AUTOMATIC",
        },
        update: {
          intentId: intent.id,
          amount: amountEur,
          applicationFee: feeCents / 100,
          status: "REQUIRES_PAYMENT_METHOD",
        },
      }),
    ]);

    return NextResponse.json({
      clientSecret: intent.client_secret,
      paymentIntentId: intent.id,
      applicationFeeAmount: feeCents,
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Vytvorenie platby zlyhalo.";
    console.error("[api/payments/create-intent]", error);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
