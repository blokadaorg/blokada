import { driver } from "@wdio/globals";

const APP_STATE_NOT_RUNNING = 1;
const APP_STATE_RUNNING_IN_FOREGROUND = 4;

async function queryAppState(bundleId: string): Promise<number> {
  return driver.execute("mobile: queryAppState", { bundleId });
}

export async function waitForAppForeground(bundleId: string, timeout = 20000): Promise<void> {
  await driver.waitUntil(
    async () => {
      const state = await queryAppState(bundleId);
      return state === APP_STATE_RUNNING_IN_FOREGROUND;
    },
    {
      timeout,
      timeoutMsg: `App ${bundleId} did not reach foreground state within ${timeout}ms`
    }
  );
}

export async function waitForAppTermination(bundleId: string, timeout = 10000): Promise<void> {
  await driver.waitUntil(
    async () => {
      const state = await queryAppState(bundleId);
      return state === APP_STATE_NOT_RUNNING;
    },
    {
      timeout,
      timeoutMsg: `App ${bundleId} did not terminate within ${timeout}ms`
    }
  );
}

export async function terminateApp(bundleId: string): Promise<void> {
  try {
    await driver.execute("mobile: terminateApp", { bundleId });
  } catch (error) {
    console.warn(`terminateApp failed for ${bundleId}: ${String(error)}`);
  }
  await waitForAppTermination(bundleId).catch(() => undefined);
}

export async function launchApp(bundleId: string): Promise<void> {
  await driver.execute("mobile: launchApp", { bundleId });
  await waitForAppForeground(bundleId);
}

export async function activateApp(bundleId: string): Promise<void> {
  try {
    await driver.activateApp(bundleId);
  } catch (error) {
    console.warn(`activateApp fell back to launch for ${bundleId}: ${String(error)}`);
    await driver.execute("mobile: activateApp", { bundleId });
  }
  await waitForAppForeground(bundleId);
}

export async function removeAppIfPresent(bundleId: string): Promise<void> {
  try {
    const isInstalled = await driver.isAppInstalled(bundleId);
    if (!isInstalled) {
      return;
    }
    await driver.removeApp(bundleId);
    await waitForAppTermination(bundleId).catch(() => undefined);
  } catch (error) {
    console.warn(`removeAppIfPresent failed for ${bundleId}: ${String(error)}`);
  }
}

export async function switchToAppViaAppSwitcher(
  bundleId: string,
  appLabel?: string
): Promise<void> {
  const rect = await driver.getWindowRect();
  const startX = Math.round(rect.width / 2);
  const startY = Math.round(rect.height * 0.92);
  const endY = Math.round(rect.height * 0.35);

  try {
    await driver.execute("mobile: dragFromToForDuration", {
      duration: 0.7,
      fromX: startX,
      fromY: startY,
      toX: startX,
      toY: endY
    });
    await driver.pause(800);
  } catch (error) {
    console.warn(`App switcher gesture failed (${String(error)}). Falling back to activateApp.`);
    await activateApp(bundleId);
    return;
  }

  const label = (appLabel ?? "").trim();
  const selectors: string[] = [];
  if (label.length > 0) {
    selectors.push(
      `-ios predicate string: type == 'XCUIElementTypeApplication' AND (name == '${label}' OR label == '${label}')`,
      `-ios predicate string: type == 'XCUIElementTypeOther' AND (name == '${label}' OR label == '${label}')`
    );
  }
  selectors.push(
    `-ios predicate string: type == 'XCUIElementTypeApplication' AND (name == '${bundleId}' OR label == '${bundleId}')`
  );

  for (const selector of selectors) {
    try {
      const element = await driver.$(selector);
      if (await element.isExisting()) {
        await element.click();
        await waitForAppForeground(bundleId);
        return;
      }
    } catch (error) {
      console.warn(`App switcher selector '${selector}' failed: ${String(error)}`);
    }
  }

  console.warn("App card not found in switcher; activating app directly.");
  await activateApp(bundleId);
}
