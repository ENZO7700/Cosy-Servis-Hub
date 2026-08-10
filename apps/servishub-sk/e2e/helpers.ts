import { expect, type Page } from "@playwright/test";
import { config as loadEnv } from "dotenv";

loadEnv({ path: ".env.local" });
loadEnv();

export const DEMO_PROVIDER_SLUG = "e2e-upratovanie-ba";
export const DEMO_PROVIDER_NAME = "E2E Upratovanie BA";

export function hasSupabaseAuthEnv(): boolean {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL?.trim() &&
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim(),
  );
}

export function hasDatabaseEnv(): boolean {
  const url = process.env.DIRECT_URL ?? process.env.DATABASE_URL;
  if (!url?.trim()) return false;
  return !/YOUR_PROJECT|PASSWORD|placeholder/i.test(url);
}

export function hasServiceRoleEnv(): boolean {
  return Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY?.trim());
}

export function hasStripeEnv(): boolean {
  return Boolean(
    process.env.STRIPE_SECRET_KEY?.trim() &&
      process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY?.trim(),
  );
}

export function hasSeedCredentials(): boolean {
  return Boolean(
    hasDatabaseEnv() &&
      hasServiceRoleEnv() &&
      process.env.E2E_PROVIDER_PASSWORD?.trim() &&
      process.env.E2E_CUSTOMER_PASSWORD?.trim(),
  );
}

export function providerCredentials(): { email: string; password: string } {
  return {
    email:
      process.env.E2E_PROVIDER_EMAIL?.trim() || "e2e-provider@example.com",
    password: process.env.E2E_PROVIDER_PASSWORD?.trim() || "",
  };
}

export function customerCredentials(): { email: string; password: string } {
  return {
    email:
      process.env.E2E_CUSTOMER_EMAIL?.trim() || "e2e-customer@example.com",
    password: process.env.E2E_CUSTOMER_PASSWORD?.trim() || "",
  };
}

export function uniqueEmail(prefix: string): string {
  // Avoid reserved domains (.local, example.com) — Supabase Auth rejects them on signup.
  return `${prefix}.${Date.now()}@mailinator.com`;
}

/** Next Mon–Fri Date in local timezone (at noon). */
export function nextWeekdayDate(from = new Date()): Date {
  const date = new Date(from);
  date.setHours(12, 0, 0, 0);
  date.setDate(date.getDate() + 1);
  while (date.getDay() === 0 || date.getDay() === 6) {
    date.setDate(date.getDate() + 1);
  }
  return date;
}

export function nextWeekdayDateString(from = new Date()): string {
  const date = nextWeekdayDate(from);
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/** Slovak long month name (react-day-picker sk locale). */
const SK_MONTHS = [
  "januára",
  "februára",
  "marca",
  "apríla",
  "mája",
  "júna",
  "júla",
  "augusta",
  "septembra",
  "októbra",
  "novembra",
  "decembra",
] as const;

const SK_WEEKDAYS = [
  "nedeľa",
  "pondelok",
  "utorok",
  "streda",
  "štvrtok",
  "piatok",
  "sobota",
] as const;

/** Aria label fragment matching DayPicker SK buttons, e.g. "pondelok 10. augusta 2026". */
export function skDayAriaName(date: Date): RegExp {
  const weekday = SK_WEEKDAYS[date.getDay()];
  const day = date.getDate();
  const month = SK_MONTHS[date.getMonth()];
  const year = date.getFullYear();
  return new RegExp(`${weekday}\\s+${day}\\.\\s+${month}\\s+${year}`, "i");
}

export async function pickCalendarDay(page: Page, date = nextWeekdayDate()): Promise<void> {
  const name = skDayAriaName(date);
  const btn = page.getByRole("button", { name });
  // Navigate months if needed (max 2 clicks forward)
  for (let i = 0; i < 3; i += 1) {
    if (await btn.count()) {
      await btn.click();
      return;
    }
    await page.getByRole("button", { name: /ďalší mesiac|next month/i }).click();
  }
  await btn.click({ timeout: 10_000 });
}

export async function loginAs(
  page: Page,
  email: string,
  password: string,
  next = "/",
): Promise<void> {
  await page.goto(`/login?next=${encodeURIComponent(next)}`);
  await page.locator("#email").fill(email);
  await page.locator("#password").fill(password);
  await page.getByRole("button", { name: "Prihlásiť sa" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"), {
    timeout: 30_000,
  });
}

export async function logout(page: Page): Promise<void> {
  await page.goto("/auth/logout");
  await expect(page).toHaveURL(/\/$/);
}

export async function signupCustomer(
  page: Page,
  input: {
    fullName: string;
    email: string;
    password: string;
    next?: string;
  },
): Promise<"session" | "confirm-email"> {
  const next = input.next ?? "/";
  await page.goto(`/signup?next=${encodeURIComponent(next)}`);
  await page.locator("#fullName").fill(input.fullName);
  await page.locator("#email").fill(input.email);
  await page.locator("#password").fill(input.password);
  await page.locator('input[name="role"][value="CUSTOMER"]').check();
  await page.getByRole("button", { name: "Vytvoriť účet" }).click();
  return await settleSignup(page);
}

export async function signupProvider(
  page: Page,
  input: {
    fullName: string;
    email: string;
    password: string;
    promoCode?: string;
  },
): Promise<"session" | "confirm-email"> {
  await page.goto("/signup");
  await page.locator("#fullName").fill(input.fullName);
  await page.locator("#email").fill(input.email);
  await page.locator("#password").fill(input.password);
  await page.locator('input[name="role"][value="PROVIDER"]').check();
  if (input.promoCode) {
    await page.locator("#promoCode").fill(input.promoCode);
  }
  await page.getByRole("button", { name: "Vytvoriť účet" }).click();
  return await settleSignup(page);
}

async function settleSignup(
  page: Page,
): Promise<"session" | "confirm-email"> {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    const path = new URL(page.url()).pathname;
    if (!path.startsWith("/signup")) {
      return "session";
    }

    const status = page.getByRole("status").first();
    if (await status.isVisible().catch(() => false)) {
      const text = (await status.innerText()).trim();
      if (/Skontrolujte email|potvrďte registráciu/i.test(text)) {
        return "confirm-email";
      }
      if (/rate limit/i.test(text)) {
        throw new Error(
          `Signup blocked by Supabase Auth rate limit: ${text}. Disable email confirmations or raise rate limits in Dashboard → Auth.`,
        );
      }
      if (/invalid/i.test(text)) {
        throw new Error(`Signup email rejected by Supabase: ${text}`);
      }
      throw new Error(`Signup error: ${text}`);
    }

    await page.waitForTimeout(250);
  }
  throw new Error("Signup timed out without redirect or status message");
}
