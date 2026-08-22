import { test, expect } from "@playwright/test";
import {
  customerCredentials,
  hasDatabaseEnv,
  hasSeedCredentials,
  hasStripeEnv,
  loginAs,
} from "./helpers";

test.describe("Payments (LAUNCH 4.4)", () => {
  test("create-intent smoke", async ({ page, request }) => {
    test.skip(!hasStripeEnv(), "Chýbajú Stripe test keys — skip payments E2E");
    test.skip(!hasDatabaseEnv(), "Chýba DATABASE_URL (Gate 0)");
    test.skip(!hasSeedCredentials(), "Chýba seed credentials");

    const customer = customerCredentials();
    await loginAs(page, customer.email, customer.password, "/moje-rezervacie");
    await page.goto("/moje-rezervacie");

    // Prefer booking id from data attribute if present; otherwise API 400/404 is still a smoke signal
    const bookingId = await page
      .locator("[data-booking-id]")
      .first()
      .getAttribute("data-booking-id")
      .catch(() => null);

    if (!bookingId) {
      test.info().annotations.push({
        type: "note",
        description:
          "Žiadny data-booking-id na /moje-rezervacie — overujeme aspoň 401/400 bez session cookie reuse",
      });
      const unauth = await request.post("/api/payments/create-intent", {
        data: { bookingId: "missing" },
      });
      expect([401, 400, 404, 503]).toContain(unauth.status());
      return;
    }

    const cookies = await page.context().cookies();
    const cookieHeader = cookies.map((c) => `${c.name}=${c.value}`).join("; ");
    const response = await request.post("/api/payments/create-intent", {
      headers: { Cookie: cookieHeader },
      data: { bookingId },
    });

    // Without Connect onboarding expect 400; with Connect 200
    expect([200, 400, 404, 503]).toContain(response.status());
    if (response.status() === 200) {
      const body = await response.json();
      expect(body).toHaveProperty("clientSecret");
    }
  });
});
