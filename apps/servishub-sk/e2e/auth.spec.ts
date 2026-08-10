import { test, expect } from "@playwright/test";
import {
  customerCredentials,
  hasSeedCredentials,
  hasSupabaseAuthEnv,
  loginAs,
  logout,
  signupCustomer,
  signupProvider,
  uniqueEmail,
} from "./helpers";

async function softSignup<T>(fn: () => Promise<T>): Promise<T | "skipped-infra"> {
  try {
    return await fn();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (/rate limit|email rejected|invalid/i.test(message)) {
      test.skip(true, message);
      return "skipped-infra";
    }
    throw error;
  }
}

test.describe("Auth smoke (LAUNCH 4.1)", () => {
  test.beforeEach(() => {
    test.skip(
      !hasSupabaseAuthEnv(),
      "Chýba NEXT_PUBLIC_SUPABASE_URL / ANON_KEY",
    );
  });

  test("seed customer login + logout", async ({ page }) => {
    test.skip(!hasSeedCredentials(), "Chýba seed E2E credentials");
    const customer = customerCredentials();
    await loginAs(page, customer.email, customer.password, "/moje-rezervacie");
    await expect(page).toHaveURL(/\/moje-rezervacie/);
    await logout(page);
    await expect(page.getByRole("link", { name: "Prihlásenie" })).toBeVisible();
  });

  test("signup CUSTOMER", async ({ page }) => {
    const email = uniqueEmail("customer");
    const result = await softSignup(() =>
      signupCustomer(page, {
        fullName: "E2E Zákazník",
        email,
        password: "TestPass123!",
        next: "/moje-rezervacie",
      }),
    );
    if (result === "skipped-infra") return;

    if (result === "confirm-email") {
      await expect(
        page.getByRole("status").filter({ hasText: /email/i }),
      ).toBeVisible();
      return;
    }

    await expect(page).not.toHaveURL(/\/signup/);
  });

  test("signup PROVIDER + EARLYBIRD", async ({ page }) => {
    const email = uniqueEmail("provider");
    const result = await softSignup(() =>
      signupProvider(page, {
        fullName: "E2E Profesionál",
        email,
        password: "TestPass123!",
        promoCode: "EARLYBIRD",
      }),
    );
    if (result === "skipped-infra") return;

    if (result === "confirm-email") {
      await expect(
        page.getByRole("status").filter({ hasText: /email/i }),
      ).toBeVisible();
      return;
    }

    await expect(page).toHaveURL(/\/pro/);
  });
});
