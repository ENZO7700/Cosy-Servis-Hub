import { expect, test } from '@playwright/test';
import { loadEnv } from '../helpers/env';

const env = loadEnv();

test.describe('Integrity · deployed Flutter web', () => {
  test('homepage returns 200 and loads Flutter bootstrap', async ({
    page,
    request,
  }) => {
    const health = await request.get(env.baseUrl);
    expect(health.status()).toBe(200);

    const consoleErrors: string[] = [];
    const failedRequests: string[] = [];

    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('response', (response) => {
      const url = response.url();
      // Core app assets / known critical endpoints
      const critical =
        url.includes('/main.dart.js') ||
        url.includes('/flutter_bootstrap.js') ||
        url.includes('/flutter.js') ||
        (url.includes('/rest/v1/projects') && response.status() >= 400) ||
        (url.includes('/rest/v1/bugs') && response.status() >= 400);
      if (critical && response.status() >= 400) {
        failedRequests.push(`${response.status()} ${url}`);
      }
    });

    await page.goto(env.baseUrl, { waitUntil: 'domcontentloaded' });

    // Flutter web shell (prefer flutter-view; body may be reported hidden under COOP/embedding)
    await expect(page.locator('flutter-view').first()).toBeVisible({
      timeout: 30_000,
    });
    await expect(page.locator('flt-glass-pane').first()).toBeAttached({
      timeout: 30_000,
    });

    // Wait for main.dart.js to load (compiled app)
    await page.waitForFunction(
      () =>
        [...document.scripts].some((s) =>
          (s.src || '').includes('main.dart.js'),
        ),
      { timeout: 30_000 },
    );

    // Give network a moment for initial REST calls
    await page.waitForTimeout(2500);

    const restFailures = failedRequests.filter((line) =>
      line.includes('/rest/v1/'),
    );
    expect(
      restFailures,
      `Unexpected REST failures:\n${restFailures.join('\n')}`,
    ).toEqual([]);

    // Ignore COOP popup noise from Google auth, keep hard failures
    const hardConsole = consoleErrors.filter(
      (line) =>
        !line.includes('Cross-Origin-Opener-Policy') &&
        !line.includes('window.close') &&
        !line.includes('favicon'),
    );

    // Soft assert: log remaining console errors but fail only on PGRST/table missing
    const tableMissing = hardConsole.filter(
      (line) =>
        line.includes('PGRST205') || line.includes('Could not find the table'),
    );
    expect(tableMissing, tableMissing.join('\n')).toEqual([]);
  });

  test('main.dart.js is served and contains baked secrets markers', async ({
    request,
  }) => {
    const response = await request.get(`${env.baseUrl}/main.dart.js`);
    expect(response.status()).toBe(200);
    const body = await response.text();
    expect(body.length).toBeGreaterThan(100_000);
    // Project markers from secrets/build
    expect(body).toContain('machinegunslots');
    expect(body).toMatch(/kpsnwpuydqqojwmrnkdy|supabase\.co/);
  });

  test('SPA rewrite serves index for deep routes', async ({ request }) => {
    const response = await request.get(`${env.baseUrl}/crm`);
    // Flutter hosting should SPA-rewrite to index.html, not hard 404 text
    expect(response.status()).toBe(200);
    const body = await response.text();
    expect(body.toLowerCase()).toContain('<html');
  });
});
