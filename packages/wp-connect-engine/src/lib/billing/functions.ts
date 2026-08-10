import { createServerFn } from "@tanstack/react-start";
import { getRequest } from "@tanstack/react-start/server";
import { authMiddleware } from "@/lib/auth/middleware";
import { getSessionUser } from "@/lib/auth/verify.server";
import {
  createBillingPortalSession,
  createCheckoutSession,
  getBillingSnapshot,
  setUserPlanFree,
} from "@/lib/stripe/server";
import {
  getAppOrigin,
  isStripeConfigured,
  type PaidPlanTier,
} from "@/lib/stripe/config";

async function originFromRequest(): Promise<string> {
  try {
    const req = getRequest();
    return getAppOrigin(req);
  } catch {
    return getAppOrigin();
  }
}

export const getMyBilling = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .handler(async ({ context }) => {
    return getBillingSnapshot(context.userId);
  });

export const createCheckout = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator((plan: PaidPlanTier) => {
    if (plan !== "PRO" && plan !== "ENTERPRISE") {
      throw new Error("Invalid plan");
    }
    return plan;
  })
  .handler(async ({ context, data: plan }) => {
    if (!isStripeConfigured()) {
      throw new Error(
        "Stripe is not configured (STRIPE_SECRET_KEY / STRIPE_PRICE_*)",
      );
    }
    const user = await getSessionUser();
    const origin = await originFromRequest();
    return createCheckoutSession({
      userId: context.userId,
      email: user?.email ?? null,
      plan,
      origin,
    });
  });

export const createPortal = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .handler(async ({ context }) => {
    if (!isStripeConfigured()) {
      throw new Error("Stripe is not configured");
    }
    const user = await getSessionUser();
    const origin = await originFromRequest();
    return createBillingPortalSession({
      userId: context.userId,
      email: user?.email ?? null,
      origin,
    });
  });

/** Activate FREE when no active Stripe subscription */
export const activateFreePlan = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .handler(async ({ context }) => {
    const snap = await getBillingSnapshot(context.userId);
    if (
      snap.stripeSubscriptionId &&
      (snap.status === "active" || snap.status === "trialing")
    ) {
      throw new Error(
        "Cancel or switch plan in the Stripe Customer Portal first.",
      );
    }
    await setUserPlanFree(context.userId);
    return getBillingSnapshot(context.userId);
  });
