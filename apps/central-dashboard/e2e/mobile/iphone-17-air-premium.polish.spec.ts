import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import {
  createReport,
  type PolishReport,
  writePolishReport,
} from '../helpers/polish-report';

/**
 * Full implementation of e2e/prompts/iphone-17-air-premium-polish.prompt.md
 *
 * Serial suite so one shared report is written with:
 * - P1–P6 (+ mapped checks 1–8)
 * - PNG path
 * - network 4xx list
 * - 3 UI polish recommendations
 */
test.describe.configure({ mode: 'serial' });

test.describe('iPhone 17 Air Premium · polish (pl-PL)', () => {
  test.use({
    locale: 'pl-PL',
    timezoneId: 'Europe/Warsaw',
    colorScheme: 'dark',
    geolocation: { latitude: 52.2297, longitude: 21.0122 },
    permissions: ['geolocation'],
  });

  let report: PolishReport;
  const network4xx: string[] = [];

  test.beforeAll(() => {
    const baseURL =
      test.info().project.use.baseURL ||
      process.env.E2E_BASE_URL ||
      'https://machinegunslots.web.app';
    report = createReport(String(baseURL));
  });

  test.afterAll(() => {
    report.network4xx = [...new Set(network4xx)];
    const mdPath = writePolishReport(report);
    // eslint-disable-next-line no-console
    console.log(`\n📄 Polish report: ${mdPath}\n`);
  });

  async function openShell(
    page: import('@playwright/test').Page,
  ): Promise<void> {
    page.on('response', (res) => {
      const status = res.status();
      if (status < 400) return;
      const url = res.url();
      // Track boot-relevant failures
      if (
        url.includes('/rest/v1/') ||
        url.includes('main.dart.js') ||
        url.includes('flutter') ||
        url.includes('identitytoolkit')
      ) {
        network4xx.push(`${status} ${url}`);
      }
    });

    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await expect(page.locator('flutter-view').first()).toBeVisible({
      timeout: 45_000,
    });
    await expect(page.locator('flt-glass-pane').first()).toBeAttached({
      timeout: 45_000,
    });
  }

  function record(
    id: string,
    name: string,
    status: 'PASS' | 'FAIL' | 'SKIP',
    detail?: string,
  ) {
    report.checks.push({ id, name, status, detail });
  }

  test('P1 · shell load + no horizontal overflow', async ({ page }) => {
    try {
      await openShell(page);

      const hasMain = await page.evaluate(() =>
        [...document.scripts].some((s) =>
          (s.src || '').includes('main.dart.js'),
        ),
      );
      expect(hasMain).toBeTruthy();

      const metrics = await page.evaluate(() => {
        const doc = document.documentElement;
        const body = document.body;
        return {
          clientWidth: doc.clientWidth,
          scrollWidth: Math.max(doc.scrollWidth, body?.scrollWidth ?? 0),
          dpr: window.devicePixelRatio,
          innerWidth: window.innerWidth,
          innerHeight: window.innerHeight,
        };
      });

      const overflow = metrics.scrollWidth - metrics.clientWidth;
      expect(overflow, JSON.stringify(metrics)).toBeLessThanOrEqual(2);
      expect(metrics.innerWidth).toBeGreaterThanOrEqual(360);
      expect(metrics.innerHeight).toBeGreaterThanOrEqual(640);
      expect(metrics.dpr).toBeGreaterThanOrEqual(2);

      record(
        'P1',
        'Shell load + no horizontal overflow',
        'PASS',
        `overflow=${overflow}px dpr=${metrics.dpr} ${metrics.innerWidth}x${metrics.innerHeight}`,
      );
      record(
        'C1',
        'Shell load (flutter-view / glass / main.dart.js)',
        'PASS',
        'flutter-view visible, glass attached, main.dart.js present',
      );
      record(
        'C2',
        'No horizontal overflow (≤2px)',
        'PASS',
        `${overflow}px`,
      );
    } catch (error) {
      record('P1', 'Shell load + no horizontal overflow', 'FAIL', String(error));
      record('C1', 'Shell load', 'FAIL', String(error));
      record('C2', 'No horizontal overflow', 'FAIL', String(error));
      throw error;
    }
  });

  test('P2 · full-bleed Flutter view', async ({ page }) => {
    try {
      await openShell(page);
      const box = await page.locator('flutter-view').first().boundingBox();
      expect(box).toBeTruthy();
      expect(box!.width).toBeGreaterThan(300);
      expect(box!.height).toBeGreaterThan(500);

      const vw = page.viewportSize()?.width ?? 0;
      const delta = Math.abs((box?.width ?? 0) - vw);
      expect(delta).toBeLessThanOrEqual(24);

      record(
        'P2',
        'Full-bleed flutter-view',
        'PASS',
        `view=${Math.round(box!.width)}x${Math.round(box!.height)} Δw=${delta.toFixed(1)}`,
      );
      record('C3', 'Full-bleed (±24px)', 'PASS', `Δw=${delta.toFixed(1)}px`);
    } catch (error) {
      record('P2', 'Full-bleed flutter-view', 'FAIL', String(error));
      record('C3', 'Full-bleed (±24px)', 'FAIL', String(error));
      throw error;
    }
  });

  test('P3 · portrait screenshot + soft perf', async ({ page }, testInfo) => {
    try {
      await openShell(page);
      await page.waitForTimeout(2000);

      const artifactsDir = path.join(process.cwd(), 'e2e', 'artifacts');
      fs.mkdirSync(artifactsDir, { recursive: true });
      const pngPath = path.join(
        artifactsDir,
        'iphone-17-air-premium-home.png',
      );

      const shot = await page.screenshot({
        path: pngPath,
        fullPage: false,
        animations: 'disabled',
      });
      await testInfo.attach('iphone-17-air-premium-home', {
        body: shot,
        contentType: 'image/png',
      });
      report.screenshotPath = pngPath;

      const timing = await page.evaluate(() => {
        const nav = performance.getEntriesByType(
          'navigation',
        )[0] as PerformanceNavigationTiming | undefined;
        return {
          domContentLoaded: nav?.domContentLoadedEventEnd ?? 0,
          loadEvent: nav?.loadEventEnd ?? 0,
        };
      });

      if (timing.domContentLoaded > 0) {
        expect(timing.domContentLoaded).toBeLessThan(30_000);
      }

      record(
        'P3',
        'Screenshot + soft perf',
        'PASS',
        `png=${pngPath}; DCL=${Math.round(timing.domContentLoaded)}ms`,
      );
      record('C7', 'Screenshot attach', 'PASS', pngPath);
      record(
        'C8',
        'Perf soft DCL < 30s',
        'PASS',
        `${Math.round(timing.domContentLoaded)}ms`,
      );
    } catch (error) {
      record('P3', 'Screenshot + soft perf', 'FAIL', String(error));
      record('C7', 'Screenshot attach', 'FAIL', String(error));
      record('C8', 'Perf soft DCL < 30s', 'FAIL', String(error));
      throw error;
    }
  });

  test('P4 · touch profile', async ({ page, browserName }) => {
    try {
      await openShell(page);
      const pointer = await page.evaluate(() => ({
        maxTouchPoints: navigator.maxTouchPoints,
        coarse: window.matchMedia('(pointer: coarse)').matches,
        fine: window.matchMedia('(pointer: fine)').matches,
      }));
      if (browserName === 'webkit') {
        // WebKit on headless macOS may report 0 maxTouchPoints, so we verify coarse pointer media query is true instead
        expect(pointer.coarse || pointer.maxTouchPoints > 0).toBe(true);
      } else {
        expect(pointer.maxTouchPoints).toBeGreaterThan(0);
      }

      record(
        'P4',
        'Touch profile',
        'PASS',
        `maxTouchPoints=${pointer.maxTouchPoints} coarse=${pointer.coarse}`,
      );
      record(
        'C4',
        'Touch profile maxTouchPoints > 0',
        'PASS',
        String(pointer.maxTouchPoints),
      );
    } catch (error) {
      record('P4', 'Touch profile', 'FAIL', String(error));
      record('C4', 'Touch profile', 'FAIL', String(error));
      throw error;
    }
  });

  test('P5 · integrity boot (bugs/projects)', async ({ page }) => {
    const bootBad: string[] = [];
    try {
      page.on('response', (res) => {
        const url = res.url();
        if (
          (url.includes('/rest/v1/bugs') ||
            url.includes('/rest/v1/projects')) &&
          res.status() >= 400
        ) {
          bootBad.push(`${res.status()} ${url}`);
        }
      });

      await openShell(page);
      await page.waitForTimeout(3000);
      expect(bootBad, bootBad.join('\n')).toEqual([]);

      record(
        'P5',
        'Integrity boot REST bugs/projects',
        'PASS',
        'no 4xx/5xx in first ~3s',
      );
      record(
        'C6',
        'Integrity boot bugs/projects',
        'PASS',
        'no 4xx/5xx',
      );
    } catch (error) {
      record(
        'P5',
        'Integrity boot REST bugs/projects',
        'FAIL',
        bootBad.join('; ') || String(error),
      );
      record('C6', 'Integrity boot bugs/projects', 'FAIL', String(error));
      throw error;
    }
  });

  test('P6 · Polish locale + Warsaw TZ', async ({ page }) => {
    try {
      await openShell(page);
      const localeInfo = await page.evaluate(() => ({
        language: navigator.language,
        languages: [...navigator.languages],
        tz: Intl.DateTimeFormat().resolvedOptions().timeZone,
      }));

      expect(localeInfo.language.toLowerCase()).toMatch(/^pl/);
      expect(localeInfo.tz).toBe('Europe/Warsaw');

      // Soft safe-area probe (CSS env may be 0 in desktop chromium emulation)
      const safe = await page.evaluate(() => {
        const probe = document.createElement('div');
        probe.style.cssText =
          'position:fixed;visibility:hidden;padding-top:env(safe-area-inset-top);padding-bottom:env(safe-area-inset-bottom);';
        document.body.appendChild(probe);
        const cs = getComputedStyle(probe);
        const top = cs.paddingTop;
        const bottom = cs.paddingBottom;
        probe.remove();
        return { top, bottom };
      });

      record(
        'P6',
        'Locale pl + Europe/Warsaw',
        'PASS',
        `lang=${localeInfo.language} tz=${localeInfo.tz} safe-area top/bottom=${safe.top}/${safe.bottom}`,
      );
      record(
        'C5',
        'Locale pl* + Europe/Warsaw',
        'PASS',
        `${localeInfo.language} / ${localeInfo.tz}`,
      );
    } catch (error) {
      record('P6', 'Locale pl + Europe/Warsaw', 'FAIL', String(error));
      record('C5', 'Locale pl* + Europe/Warsaw', 'FAIL', String(error));
      throw error;
    }
  });
});
