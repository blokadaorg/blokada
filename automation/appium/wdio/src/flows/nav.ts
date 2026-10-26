import { $, driver } from "@wdio/globals";

import { AutomationIds } from "../support/automationIds.js";
import { byId, settleNavigation, tap } from "../support/platform.js";

const screenTitleSelector = () => byId(AutomationIds.screenTitle);
const navBackSelector = () => byId(AutomationIds.navBack);
const settingsExceptionsSelector = () => byId(AutomationIds.settingsExceptions);
const settingsRetentionSelector = () => byId(AutomationIds.settingsRetention);
const exceptionsTabBlockedSelector = () => byId(AutomationIds.exceptionsTabBlocked);
const retentionToggleSelector = () => byId(AutomationIds.retentionToggle);

interface WaitForScreenOptions {
  withTitle?: boolean;
  timeout?: number;
}

/**
 * Wait for a screen body marker to render. Every pushed screen also renders the
 * top-bar title, so assert that too unless `withTitle` is false — Home is at nav
 * depth 1 with no top bar, so pass `withTitle: false` for it.
 */
export async function waitForScreen(
  screenId: string,
  { withTitle = true, timeout = 15000 }: WaitForScreenOptions = {}
): Promise<void> {
  await (await $(byId(screenId))).waitForExist({ timeout });
  if (withTitle) {
    await (await $(screenTitleSelector())).waitForExist({ timeout });
  }
}

/**
 * Tap a Home-hub entry control (gear / card button) and wait for its destination
 * screen to render. V6 has no bottom tab bar — Home is the only navigation hub,
 * same path as `account.ts::openSettingsScreen`.
 */
export async function openHubScreen(
  buttonId: string,
  screenId: string,
  timeout = 15000
): Promise<void> {
  const button = await $(byId(buttonId));
  await button.waitForExist({ timeout });
  await tap(button);
  await waitForScreen(screenId, { timeout });
  await settleNavigation();
}

/**
 * Pop one pushed route via the top-bar back control — the only pop affordance,
 * since routes use MaterialWithModalsPageRoute with no iOS edge-swipe. Optionally
 * assert arrival on an expected screen marker.
 */
export async function tapBack(expectScreenId?: string, timeout = 15000): Promise<void> {
  const back = await $(navBackSelector());
  await back.waitForExist({ timeout });
  await tap(back);
  if (expectScreenId) {
    await (await $(byId(expectScreenId))).waitForExist({ timeout });
  } else {
    await driver.pause(500);
  }
  await settleNavigation();
}

export async function goBackToHome(timeout = 15000): Promise<void> {
  await tapBack(AutomationIds.screenHome, timeout);
}

/**
 * From the in-app Settings screen, open the Exceptions sub-page and wait for its
 * tab segments to render. Call after `openSettingsScreen()`.
 */
export async function openExceptionsSubPage(timeout = 15000): Promise<void> {
  const row = await $(settingsExceptionsSelector());
  await row.waitForExist({ timeout });
  await tap(row);
  await (await $(exceptionsTabBlockedSelector())).waitForExist({ timeout });
  await settleNavigation();
}

/**
 * From the in-app Settings screen, open the Activity/Retention sub-page and wait
 * for its toggle to render. Call after `openSettingsScreen()`.
 */
export async function openRetentionSubPage(timeout = 15000): Promise<void> {
  const row = await $(settingsRetentionSelector());
  await row.waitForExist({ timeout });
  await tap(row);
  await (await $(retentionToggleSelector())).waitForExist({ timeout });
  await settleNavigation();
}
