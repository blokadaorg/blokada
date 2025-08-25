import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './ui',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['list'], // Console output
    ['json', { outputFile: 'test-results.json' }], // JSON results file
    ['junit', { outputFile: 'test-results.xml' }] // JUnit XML file
  ],
  use: {
    baseURL: 'http://localhost:8080',
    trace: 'on-first-retry',
    screenshot: 'always',
    // Disable browser caching to ensure fresh content
    extraHTTPHeaders: {
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache'
    }
  },

  webServer: {
    command: 'python3 -m http.server 8080 > /dev/null 2>&1',
    port: 8080,
    cwd: '../',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },


  projects: [
    {
      name: 'webkit-popup',
      use: { 
        ...devices['iPhone 14 Pro'],
        // Safari extension popup dimensions (matching real iPhone appearance)
        viewport: { width: 320, height: 400 }, // Compact popup size based on real device
        // Clear browser cache and storage before each test
        storageState: undefined,
        contextOptions: {
          clearCookies: true,
          clearLocalStorage: true,
        }
      },
    },
  ]
});