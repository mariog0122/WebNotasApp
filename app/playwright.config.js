import { defineConfig, devices } from '@playwright/test'

const playwrightPort = process.env.PLAYWRIGHT_PORT || '5173'
const playwrightBaseUrl = process.env.PLAYWRIGHT_BASE_URL || `http://127.0.0.1:${playwrightPort}`

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  use: {
    baseURL: playwrightBaseUrl,
    trace: 'on-first-retry',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: process.env.PLAYWRIGHT_NO_SERVER
    ? undefined
    : {
        command: `node ./node_modules/vite/bin/vite.js --host 127.0.0.1 --port ${playwrightPort} --strictPort`,
        url: playwrightBaseUrl,
        reuseExistingServer: !process.env.CI,
        timeout: 120_000,
      },
})
