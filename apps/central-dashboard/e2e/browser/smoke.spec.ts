import { expect, test } from '@playwright/test';

/**
 * Light browser smoke. Auth popup login is not automated here
 * (requires real Google session). Checks shell render only.
 */
test.describe('Browser smoke', () => {
  test('app shell becomes interactive shell or auth screen', async ({
    page,
  }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });

    // CanvasKit Flutter often keeps body.innerText empty; assert shell nodes instead.
    await expect(page.locator('flutter-view').first()).toBeVisible({
      timeout: 30_000,
    });
    await expect(page.locator('flt-glass-pane').first()).toBeAttached({
      timeout: 30_000,
    });

    // main.dart.js loaded
    const hasMain = await page.evaluate(() =>
      [...document.scripts].some((s) => (s.src || '').includes('main.dart.js')),
    );
    expect(hasMain).toBeTruthy();
  });
});
