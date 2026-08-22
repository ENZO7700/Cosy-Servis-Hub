import { test, expect } from "@playwright/test";
import {
  DEMO_PROVIDER_NAME,
  DEMO_PROVIDER_SLUG,
  customerCredentials,
  hasDatabaseEnv,
  hasSeedCredentials,
  loginAs,
  providerCredentials,
} from "./helpers";

test.describe("Pro onboarding + orders (LAUNCH 4.2 / 4.3)", () => {
  test.beforeEach(() => {
    test.skip(!hasDatabaseEnv(), "Chýba reálny DATABASE_URL / DIRECT_URL (Gate 0)");
    test.skip(
      !hasSeedCredentials(),
      "Chýba seed credentials — pnpm db:seed + E2E_*_PASSWORD",
    );
  });

  test("profil / služba / dostupnosť / verejný slug", async ({ page }) => {
    const provider = providerCredentials();
    await loginAs(page, provider.email, provider.password, "/pro/profil");

    await page.goto("/pro/profil");
    await page.locator("#businessName").fill(DEMO_PROVIDER_NAME);
    await page.locator("#city").fill("Bratislava");
    await page.locator("#postalCode").fill("81101");
    await page.locator("#ico").fill("12345678");
    const category = page.locator('input[name="categoryIds"]').first();
    if (await category.count()) {
      await category.check();
    }
    await page.getByRole("button", { name: /Uložiť profil/i }).click();
    await expect(page.getByRole("status")).toBeVisible({ timeout: 20_000 });

    await page.goto("/pro/sluzby");
    await expect(page.getByText("Moje služby")).toBeVisible();
    await expect(page.getByText("Základné upratovanie bytu")).toBeVisible();

    await page.goto("/pro/dostupnost");
    await page.getByRole("button", { name: /Uložiť dostupnosť/i }).click();
    await expect(page.getByRole("status")).toBeVisible({ timeout: 20_000 });

    await page.goto(`/p/${DEMO_PROVIDER_SLUG}`);
    await expect(page.getByText(DEMO_PROVIDER_NAME).first()).toBeVisible();
  });

  test("provider completes booking when present", async ({ page }) => {
    const provider = providerCredentials();
    await loginAs(page, provider.email, provider.password, "/pro/objednavky");
    await page.goto("/pro/objednavky");

    await expect(page.getByRole("main").getByText("Objednávky")).toBeVisible();

    const confirmBtn = page.getByRole("button", { name: "Potvrdiť" }).first();
    const completeBtn = page.getByRole("button", { name: "Dokončiť" }).first();

    if ((await confirmBtn.count()) > 0) {
      await confirmBtn.click();
      await expect(page.getByText("Potvrdená").first()).toBeVisible({
        timeout: 15_000,
      });
    }

    if ((await page.getByRole("button", { name: "Dokončiť" }).count()) > 0) {
      await page.getByRole("button", { name: "Dokončiť" }).first().click();
      await expect(page.getByText("Dokončená").first()).toBeVisible({
        timeout: 15_000,
      });
    } else if ((await completeBtn.count()) === 0) {
      await expect(
        page.getByText(/Zatiaľ žiadne rezervácie|Nová|Potvrdená|Dokončená/i),
      ).toBeVisible();
    }

    const customer = customerCredentials();
    await page.goto("/auth/logout");
    await loginAs(page, customer.email, customer.password, "/moje-rezervacie");
    await page.goto("/moje-rezervacie");
    await expect(page.locator("body")).toBeVisible();
  });
});
