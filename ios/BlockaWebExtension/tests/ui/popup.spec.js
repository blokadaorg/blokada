import { test, expect } from '@playwright/test';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

// Load actual English translations
async function loadEnglishMessages() {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = dirname(__filename);
  const messagesPath = join(__dirname, '../../Resources/_locales/en/messages.json');
  const messagesJson = readFileSync(messagesPath, 'utf8');
  const messagesData = JSON.parse(messagesJson);
  
  // Convert from {key: {message: "text"}} to {key: "text"}
  const messages = {};
  for (const [key, value] of Object.entries(messagesData)) {
    messages[key] = value.message;
  }
  return messages;
}

// Mock browser API
async function setupMockBrowser(page, mockStatus) {
  const messages = await loadEnglishMessages();
  
  await page.addInitScript((data) => {
    window.browser = {
      runtime: {
        sendMessage: async (message) => {
          if (message.message === 'status') return { status: data.status };
          return null;
        }
      },
      i18n: {
        getMessage: (key) => {
          return data.messages[key] || key;
        }
      }
    };
    
  }, { status: mockStatus, messages });
}

// Helper to refresh status and get result
async function refreshAndGetStatus(page) {
  return await page.evaluate(async () => {
    if (window.popupTestExports?.refreshStatus) {
      const statusEl = document.getElementById('status-text');
      await window.popupTestExports.refreshStatus(statusEl);
      return {
        text: statusEl.textContent,
        className: statusEl.className
      };
    }
    return null;
  });
}

// Helper to check for black borders by ensuring body fills viewport
async function checkNoBlackBorders(page, testInfo) {
  const coverage = await page.evaluate(() => {
    const body = document.body;
    const rect = body.getBoundingClientRect();
    return {
      bodyWidth: rect.width,
      bodyHeight: rect.height,
      viewportWidth: window.innerWidth,
      viewportHeight: window.innerHeight
    };
  });
  
  console.log(`Viewport: ${coverage.viewportWidth}x${coverage.viewportHeight}, Body: ${coverage.bodyWidth}x${coverage.bodyHeight}`);
  
  // Allow 1px tolerance for rounding
  expect(coverage.bodyWidth).toBeGreaterThanOrEqual(coverage.viewportWidth - 1);
  expect(coverage.bodyHeight).toBeGreaterThanOrEqual(coverage.viewportHeight - 1);
}

test.describe('BlockaWeb Safari Extension Popup', () => {
  
  test('renders inactive state', async ({ page }, testInfo) => {
    await setupMockBrowser(page, { active: false, timestamp: "2024-12-31T23:59:59Z" });
    await page.goto('/Resources/popup.html', { waitUntil: 'networkidle' });
    
    await expect(page.locator('.logo')).toBeVisible();
    await expect(page.locator('#open-app-btn')).toContainText('Open Blokada');
    
    await refreshAndGetStatus(page);
    
    await expect(page.locator('#status-text')).toContainText('Check status in Blokada');
    await expect(page.locator('#status-text')).toHaveClass(/status-inactive/);
    
    // Check for black borders
    await checkNoBlackBorders(page, testInfo);
    
    const screenshot = await page.screenshot({ path: `ui/screenshots/popup-inactive-${testInfo.project.name}.png`, fullPage: true });
    await test.info().attach(`popup-inactive-${testInfo.project.name}`, { body: screenshot, contentType: 'image/png' });
  });

  test('renders active subscription state', async ({ page }, testInfo) => {
    await setupMockBrowser(page, { active: true, timestamp: "2099-12-31T23:59:59Z" });
    await page.goto('/Resources/popup.html', { waitUntil: 'networkidle' });
    
    await expect(page.locator('.logo')).toBeVisible();
    
    const result = await refreshAndGetStatus(page);
    console.log('Active status:', result);
    
    await expect(page.locator('#status-text')).toContainText('Blokada is active');
    await expect(page.locator('#status-text')).toHaveClass(/status-cloud/);
    
    // Check for black borders
    await checkNoBlackBorders(page, testInfo);
    
    const screenshot = await page.screenshot({ path: `ui/screenshots/popup-active-${testInfo.project.name}.png`, fullPage: true });
    await test.info().attach(`popup-active-${testInfo.project.name}`, { body: screenshot, contentType: 'image/png' });
  });

  test('renders freemium trial state', async ({ page }, testInfo) => {
    await setupMockBrowser(page, { 
      active: true, 
      timestamp: "2023-01-01T00:00:00Z",
      freemium: true,
      freemiumYoutubeUntil: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString()
    });
    await page.goto('/Resources/popup.html', { waitUntil: 'networkidle' });
    
    await expect(page.locator('.logo')).toBeVisible();
    
    const result = await refreshAndGetStatus(page);
    console.log('Trial status:', result);
    
    await expect(page.locator('#status-text')).toContainText('Free trial active');
    await expect(page.locator('#status-text')).toHaveClass(/status-trial/);
    
    // Check for black borders
    await checkNoBlackBorders(page, testInfo);
    
    const screenshot = await page.screenshot({ path: `ui/screenshots/popup-trial-${testInfo.project.name}.png`, fullPage: true });
    await test.info().attach(`popup-trial-${testInfo.project.name}`, { body: screenshot, contentType: 'image/png' });
  });

  test('renders expired subscription state', async ({ page }, testInfo) => {
    await setupMockBrowser(page, { active: true, timestamp: "2023-01-01T00:00:00Z" });
    await page.goto('/Resources/popup.html', { waitUntil: 'networkidle' });
    
    await expect(page.locator('.logo')).toBeVisible();
    
    const result = await refreshAndGetStatus(page);
    console.log('Expired status:', result);
    
    await expect(page.locator('#status-text')).toContainText('Check status in Blokada');
    
    // Check for black borders
    await checkNoBlackBorders(page, testInfo);
    
    const screenshot = await page.screenshot({ path: `ui/screenshots/popup-expired-${testInfo.project.name}.png`, fullPage: true });
    await test.info().attach(`popup-expired-${testInfo.project.name}`, { body: screenshot, contentType: 'image/png' });
  });

  test('renders essentials state', async ({ page }, testInfo) => {
    await setupMockBrowser(page, { 
      active: true, 
      timestamp: "2023-01-01T00:00:00Z", 
      freemium: true 
    });
    await page.goto('/Resources/popup.html', { waitUntil: 'networkidle' });
    
    await expect(page.locator('.logo')).toBeVisible();
    
    const result = await refreshAndGetStatus(page);
    console.log('Essentials status:', result);
    
    await expect(page.locator('#status-text')).toContainText('Safari blocking active');
    await expect(page.locator('#status-text')).toHaveClass(/status-essentials/);
    
    // Check for black borders
    await checkNoBlackBorders(page, testInfo);
    
    const screenshot = await page.screenshot({ path: `ui/screenshots/popup-essentials-${testInfo.project.name}.png`, fullPage: true });
    await test.info().attach(`popup-essentials-${testInfo.project.name}`, { body: screenshot, contentType: 'image/png' });
  });

  test('detail view navigation works', async ({ page }) => {
    const mockStatus = { active: true, timestamp: "2099-12-31T23:59:59Z" };
    await setupMockBrowser(page, mockStatus);
    await page.goto('/Resources/popup.html', { waitUntil: 'networkidle' });
    
    await expect(page.locator('#status-text')).toBeVisible();
    await refreshAndGetStatus(page);
    
    // Directly call showDetailView with the mock status to bypass async status fetch issues
    await page.evaluate((status) => {
      if (window.popupTestExports?.showDetailView) {
        window.popupTestExports.showDetailView(status);
      }
    }, mockStatus);
    
    // Wait for animation to complete
    await page.waitForTimeout(500);
    
    try {
      await expect(page.locator('#detail-view')).toBeVisible({ timeout: 2000 });
      
      // Check that features are displayed
      await expect(page.locator('#detail-features .feature-item')).toHaveCount(4);
      await expect(page.locator('#detail-features')).toContainText('Safari ad blocking');
      await expect(page.locator('#detail-features')).toContainText('Device-wide protection');
      await expect(page.locator('#detail-features')).toContainText('YouTube ads');
      await expect(page.locator('#detail-features')).toContainText('Cookie popups');
      
      // Check for checkmark icons
      await expect(page.locator('#detail-features .feature-icon')).toHaveCount(4);
      
      const screenshot = await page.screenshot({ path: 'ui/screenshots/popup-detail.png', fullPage: true });
      await test.info().attach('popup-detail', { body: screenshot, contentType: 'image/png' });
      
      // Navigate back
      await page.locator('#back-btn').click();
      await expect(page.locator('#main-view')).toBeVisible({ timeout: 2000 });
    } catch (error) {
      console.log('Detail navigation issue:', error.message);
      const screenshot = await page.screenshot({ path: 'ui/screenshots/popup-detail-failed.png', fullPage: true });
      await test.info().attach('popup-detail-failed', { body: screenshot, contentType: 'image/png' });
      throw error;
    }
  });
});