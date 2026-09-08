/**
 * Playwright config for the Canopy E2E harness.
 *
 * Targets the already-running dev server (http://localhost:5281).
 * Does NOT start or own any server process — if the server is down the
 * tests self-skip via the serversUp() helper in canopy.spec.ts.
 *
 * Run:
 *   cd desktop && npx playwright test --config tests/e2e/playwright.e2e.config.ts --reporter=list
 */
import { defineConfig } from '@playwright/test';
import path from 'path';

export default defineConfig({
  // No webServer block — we use the already-running dev server
  testDir: path.join(import.meta.dirname),
  testMatch: '*.spec.ts',
  timeout: 60_000,
  retries: 0,
  workers: 1, // serial — screenshots and terminal tests are stateful
  use: {
    baseURL: 'http://localhost:5281',
    headless: true,
    viewport: { width: 1280, height: 800 },
    screenshot: 'only-on-failure',
    video: 'off',
    trace: 'off',
  },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],
  reporter: [['list'], ['json', { outputFile: path.join(import.meta.dirname, 'results.json') }]],
});
