import "server-only";
import Stripe from "stripe";

let cached: Stripe | null = null;

/**
 * Lazy Stripe SDK. Throws a clear error only when actually called without
 * STRIPE_SECRET_KEY — import/build without keys stays safe.
 */
export function getStripe(): Stripe {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) {
    throw new Error(
      "STRIPE_SECRET_KEY is not set. Add test keys to .env.local (see .env.example).",
    );
  }
  if (!cached) {
    // apiVersion omitted — use the SDK's pinned default for the installed stripe version.
    cached = new Stripe(key);
  }
  return cached;
}

export function getCommissionPercent(): number {
  const raw = process.env.COMMISSION_PERCENT;
  const parsed = raw ? Number(raw) : 15;
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > 100) return 15;
  return parsed;
}

export function applicationFeeAmountCents(
  amountCents: number,
  commissionPercent = getCommissionPercent(),
): number {
  return Math.round((amountCents * commissionPercent) / 100);
}
