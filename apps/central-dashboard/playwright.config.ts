import { defineConfig, devices } from '@playwright/test';
import { iPhone17AirPremiumDevice } from './e2e/devices/iphone-17-air-premium';

const baseURL =
  process.env.E2E_BASE_URL?.trim() || 'https://machinegunslots.web.app';

/**
 * Playwright config for integrity + browser e2e against deployed Flutter web.
 *
 * Env:
 *   E2E_BASE_URL                 default https://machinegunslots.web.app
 *   VITE_SUPABASE_URL            optional override
 *   VITE_SUPABASE_PUBLISHABLE_KEY optional override (or read from secrets.json in tests)
 *   FIREBASE_ID_TOKEN            optional live parse_leads auth
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 2 : undefined,
  timeout: 60_000,
  expect: { timeout: 15_000 },
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'playwright-report/results.json' }],
  ],
  use: {
    baseURL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    ignoreHTTPSErrors: false,
  },
  projects: [
    {
      name: 'integrity',
      testMatch: /integrity\/.*\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
      },
    },
    {
      name: 'chromium',
      testMatch: /browser\/.*\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
      },
    },
    {
      // Full implementation of iphone-17-air-premium-polish.prompt.md
      name: 'iphone-17-air-premium',
      testMatch: /mobile\/iphone-17-air-premium.*\.spec\.ts/,
      fullyParallel: false,
      workers: 1,
      use: {
        ...devices['Desktop Chrome'],
        ...iPhone17AirPremiumDevice,
        browserName: 'chromium',
        isMobile: true,
        hasTouch: true,
      },
    },
    {
      name: 'iphone-17-air-premium-webkit',
      testMatch: /mobile\/iphone-17-air-premium.*\.spec\.ts/,
      fullyParallel: false,
      workers: 1,
      use: {
        ...iPhone17AirPremiumDevice,
        browserName: 'webkit',
        isMobile: true,
        hasTouch: true,
      },
    },
  ],
  outputDir: 'test-results',
});
