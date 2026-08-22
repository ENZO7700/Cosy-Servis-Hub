import { NextResponse } from "next/server";
import type Stripe from "stripe";
import type { PaymentStatus } from "@/generated/prisma/client";
import { isDatabaseConfigured } from "@/lib/data/db";
import { prisma } from "@/lib/prisma";
import { getStripe } from "@/lib/stripe/client";

export const runtime = "nodejs";

function mapIntentStatus(status: Stripe.PaymentIntent.Status): PaymentStatus {
  switch (status) {
    case "requires_payment_method":
      return "REQUIRES_PAYMENT_METHOD";
    case "requires_confirmation":
      return "REQUIRES_CONFIRMATION";
    case "requires_action":
      return "REQUIRES_ACTION";
    case "processing":
      return "PROCESSING";
    case "requires_capture":
      return "REQUIRES_CAPTURE";
    case "succeeded":
      return "SUCCEEDED";
    case "canceled":
      return "CANCELED";
    default:
      return "FAILED";
  }
}

async function upsertPaymentFromIntent(intent: Stripe.PaymentIntent) {
  const bookingId = intent.metadata?.bookingId;
  if (!bookingId) {
    console.warn("[webhook] PaymentIntent without bookingId metadata", intent.id);
    return;
  }

  const amountEur = intent.amount / 100;
  const feeEur =
    intent.application_fee_amount != null
      ? intent.application_fee_amount / 100
      : null;
  const status = mapIntentStatus(intent.status);
  const capturedAt =
    intent.status === "succeeded"
      ? new Date((intent.created ?? Math.floor(Date.now() / 1000)) * 1000)
      : null;

  await prisma.$transaction(async (tx) => {
    await tx.payment.upsert({
      where: { intentId: intent.id },
      create: {
        bookingId,
        intentId: intent.id,
        amount: amountEur,
        applicationFee: feeEur,
        currency: intent.currency.toUpperCase(),
        status,
        captureMethod: "AUTOMATIC",
        stripeChargeId:
          typeof intent.latest_charge === "string"
            ? intent.latest_charge
            : intent.latest_charge?.id ?? null,
        webhookPayload: intent as unknown as object,
        capturedAt,
      },
      update: {
        status,
        applicationFee: feeEur,
        stripeChargeId:
          typeof intent.latest_charge === "string"
            ? intent.latest_charge
            : intent.latest_charge?.id ?? null,
        webhookPayload: intent as unknown as object,
        capturedAt,
      },
    });

    await tx.booking.update({
      where: { id: bookingId },
      data: {
        stripePaymentIntentId: intent.id,
        ...(intent.status === "succeeded"
          ? { status: "CONFIRMED", capturedAt: capturedAt ?? new Date() }
          : {}),
        ...(intent.status === "canceled" ? { status: "CANCELLED" } : {}),
      },
    });
  });
}

export async function POST(request: Request) {
  if (!isDatabaseConfigured()) {
    return NextResponse.json(
      { error: "Databáza nie je nakonfigurovaná." },
      { status: 503 },
    );
  }

  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!webhookSecret) {
    return NextResponse.json(
      { error: "STRIPE_WEBHOOK_SECRET is not set." },
      { status: 503 },
    );
  }

  const signature = request.headers.get("stripe-signature");
  if (!signature) {
    return NextResponse.json({ error: "Missing stripe-signature" }, { status: 400 });
  }

  const rawBody = await request.text();

  let event: Stripe.Event;
  try {
    const stripe = getStripe();
    event = stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
  } catch (error) {
    console.error("[webhook] signature verification failed:", error);
    return NextResponse.json({ error: "Invalid signature" }, { status: 400 });
  }

  try {
    switch (event.type) {
      case "payment_intent.succeeded":
      case "payment_intent.payment_failed":
      case "payment_intent.canceled":
      case "payment_intent.processing":
        await upsertPaymentFromIntent(event.data.object as Stripe.PaymentIntent);
        break;
      default:
        break;
    }
  } catch (error) {
    console.error("[webhook] handler failed:", error);
    return NextResponse.json({ error: "Webhook handler failed" }, { status: 500 });
  }

  return NextResponse.json({ received: true });
}
