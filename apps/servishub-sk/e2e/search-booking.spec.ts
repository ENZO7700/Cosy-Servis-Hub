import { test, expect } from "@playwright/test";
import {
  DEMO_PROVIDER_NAME,
  DEMO_PROVIDER_SLUG,
  customerCredentials,
  hasDatabaseEnv,
  hasSeedCredentials,
  loginAs,
  nextWeekdayDate,
  pickCalendarDay,
} from "./helpers";

test.describe("Search + booking (LAUNCH 4.3)", () => {
  test.beforeEach(() => {
    test.skip(!hasDatabaseEnv(), "Chýba reálny DATABASE_URL / DIRECT_URL (Gate 0)");
    test.skip(
      !hasSeedCredentials(),
      "Chýba seed credentials — pnpm db:seed + E2E_*_PASSWORD",
    );
  });

  test("hladat → provider → rezervácia → moje-rezervacie", async ({
    page,
  }) => {
    const customer = customerCredentials();
    await loginAs(page, customer.email, customer.password, "/hladat");

    await page.goto("/hladat?city=Bratislava");
    await expect(
      page.getByRole("link", { name: new RegExp(DEMO_PROVIDER_NAME, "i") }).first(),
    ).toBeVisible({ timeout: 20_000 });

    await page.goto(`/p/${DEMO_PROVIDER_SLUG}`);
    await expect(page.getByText(DEMO_PROVIDER_NAME).first()).toBeVisible();

    await pickCalendarDay(page, nextWeekdayDate());

    await expect(page.getByText("Voľné termíny")).toBeVisible();
    const freeSlot = page
      .locator("button:not([disabled])")
      .filter({ hasText: /^\d{2}:\d{2}$/ })
      .first();
    await expect(freeSlot).toBeVisible({ timeout: 20_000 });
    await freeSlot.click();

    await page.locator("#addressLine").fill("Testovacia 1");
    await page.locator("#city").fill("Bratislava");
    await page.locator("#postalCode").fill("81101");
    await page.locator("#notes").fill("E2E booking");
    await page.getByRole("button", { name: "Odoslať rezerváciu" }).click();

    await expect(page.getByText(/Rezervácia bola vytvorená/i)).toBeVisible({
      timeout: 30_000,
    });

    await page.goto("/moje-rezervacie");
    await expect(
      page.getByText(/E2E Upratovanie BA|Základné upratovanie/i).first(),
    ).toBeVisible();
  });

  test("double-booking same slot fails", async ({ page, browser }) => {
    const customer = customerCredentials();
    const day = nextWeekdayDate();
    await loginAs(
      page,
      customer.email,
      customer.password,
      `/p/${DEMO_PROVIDER_SLUG}`,
    );
    await page.goto(`/p/${DEMO_PROVIDER_SLUG}`);
    await pickCalendarDay(page, day);

    const slotBtn = page
      .locator("button:not([disabled])")
      .filter({ hasText: /^\d{2}:\d{2}$/ })
      .first();
    await expect(slotBtn).toBeVisible({ timeout: 20_000 });
    const slotLabel = (await slotBtn.innerText()).trim();
    await slotBtn.click();

    await page.locator("#addressLine").fill("Konflikt 1");
    await page.locator("#city").fill("Bratislava");
    await page.locator("#postalCode").fill("81101");
    await page.getByRole("button", { name: "Odoslať rezerváciu" }).click();
    await expect(page.getByText(/Rezervácia bola vytvorená/i)).toBeVisible({
      timeout: 30_000,
    });

    const context2 = await browser.newContext();
    const page2 = await context2.newPage();
    await loginAs(
      page2,
      customer.email,
      customer.password,
      `/p/${DEMO_PROVIDER_SLUG}`,
    );
    await page2.goto(`/p/${DEMO_PROVIDER_SLUG}`);
    await pickCalendarDay(page2, day);

    const conflictSlot = page2.getByRole("button", { name: slotLabel });
    if (await conflictSlot.isEnabled()) {
      await conflictSlot.click();
      await page2.locator("#addressLine").fill("Konflikt 2");
      await page2.locator("#city").fill("Bratislava");
      await page2.locator("#postalCode").fill("81101");
      await page2.getByRole("button", { name: "Odoslať rezerváciu" }).click();
      await expect(
        page2
          .getByRole("status")
          .or(page2.getByText(/obsaden|konflikt|nedostupn|zlyhal/i)),
      ).toBeVisible({ timeout: 20_000 });
    } else {
      await expect(conflictSlot).toBeDisabled();
    }

    await context2.close();
  });
});
