import { defineConfig } from '@playwright/test';

const CI_ALLOW_E2E = process.env.CI_ALLOW_E2E === '1';
const isCI = Boolean(process.env.CI);

export default defineConfig({
  webServer: {
    command: 'pnpm build && pnpm preview',
    port: 4173,
    reuseExistingServer: !isCI,
  },
  testMatch: '**/*.spec.{ts,js}',
  // In CI, skip E2E unless CI_ALLOW_E2E=1 to avoid headless browser issues
  projects:
    isCI && !CI_ALLOW_E2E
      ? []
      : [
          {
            name: 'chromium',
            use: { browserName: 'chromium' },
          },
        ],
});
