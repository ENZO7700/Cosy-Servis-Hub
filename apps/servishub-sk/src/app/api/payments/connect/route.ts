import { NextResponse } from "next/server";
import { getSessionProfile } from "@/lib/auth/session";
import { isDatabaseConfigured } from "@/lib/data/db";
import { getProviderByProfileId } from "@/lib/data/providers";
import { prisma } from "@/lib/prisma";
import { getStripe } from "@/lib/stripe/client";

function appUrl(): string {
  return process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
}

/** Creates (or reuses) a Stripe Connect Express account and returns an Account Link URL. */
export async function POST() {
  if (!isDatabaseConfigured()) {
    return NextResponse.json(
      { error: "Databáza nie je nakonfigurovaná." },
      { status: 503 },
    );
  }

  try {
    const profile = await getSessionProfile();
    if (!profile) {
      return NextResponse.json({ error: "Neautorizované." }, { status: 401 });
    }
    if (profile.role !== "PROVIDER" && profile.role !== "ADMIN") {
      return NextResponse.json({ error: "Len pre profesionálov." }, { status: 403 });
    }
    const provider = await getProviderByProfileId(profile.id);
    if (!provider) {
      return NextResponse.json(
        { error: "Najprv vyplňte profil profesionála." },
        { status: 400 },
      );
    }

    const stripe = getStripe();
    let accountId = provider.stripeAccountId;

    if (!accountId) {
      const account = await stripe.accounts.create({
        type: "express",
        country: "SK",
        email: profile.email,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        business_profile: {
          name: provider.businessName,
        },
        metadata: {
          providerId: provider.id,
          profileId: profile.id,
        },
      });
      accountId = account.id;
      await prisma.provider.update({
        where: { id: provider.id },
        data: { stripeAccountId: accountId },
      });
    }

    const link = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: `${appUrl()}/pro/platby?refresh=1`,
      return_url: `${appUrl()}/pro/platby?connected=1`,
      type: "account_onboarding",
    });

    return NextResponse.json({ url: link.url });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Connect onboarding zlyhal.";
    console.error("[api/payments/connect]", error);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
