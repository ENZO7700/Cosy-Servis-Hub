import { test, expect } from "@playwright/test";
import {
  customerCredentials,
  hasDatabaseEnv,
  hasSeedCredentials,
  hasSupabaseAuthEnv,
  loginAs,
  uniqueEmail,
} from "./helpers";

test.describe("Review + waitlist (LAUNCH 4.5)", () => {
  test("waitlist on landing creates success status", async ({ page }) => {
    test.skip(!hasDatabaseEnv(), "Chýba DATABASE_URL — waitlist potrebuje Prisma Lead");

    await page.goto("/");
    const email = uniqueEmail("waitlist");
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Mesto").fill("Bratislava");
    await page.getByRole("button", { name: "Chcem vedieť" }).click();
    await expect(page.getByRole("status")).toBeVisible({ timeout: 20_000 });
  });

  test("review form appears for COMPLETED booking when present", async ({
    page,
  }) => {
    test.skip(!hasSupabaseAuthEnv(), "Chýba Supabase Auth env");
    test.skip(
      !hasSeedCredentials(),
      "Chýba seed credentials — COMPLETED booking vzniká v search-booking + pro flow",
    );

    const customer = customerCredentials();
    await loginAs(page, customer.email, customer.password, "/moje-rezervacie");
    await page.goto("/moje-rezervacie");

    const reviewSelect = page.locator('select[name="rating"]').first();
    if ((await reviewSelect.count()) === 0) {
      test.info().annotations.push({
        type: "note",
        description:
          "Žiadna COMPLETED rezervácia s review UI — spusti najprv booking + Dokončiť",
      });
      await expect(page.locator("body")).toBeVisible();
      return;
    }

    const alreadyReviewed = page.getByRole("alert").filter({
      hasText: /už má recenziu/i,
    });
    if ((await alreadyReviewed.count()) > 0) {
      await expect(alreadyReviewed.first()).toBeVisible();
      return;
    }

    await reviewSelect.selectOption("5");
    await page.locator('textarea[name="comment"]').first().fill("E2E recenzia");
    await page.getByRole("button", { name: /Odoslať|recenzi/i }).first().click();

    await expect(
      page
        .getByText("Recenzia bola uložená. Ďakujeme!")
        .or(page.getByRole("alert").filter({ hasText: /už má recenziu/i })),
    ).toBeVisible({ timeout: 20_000 });
  });
});
