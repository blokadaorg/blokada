import { $, driver } from "@wdio/globals";

import { AutomationIds } from "../support/automationIds.js";
import { byId, forPlatform, tap } from "../support/platform.js";

const rateModalSelector = () => byId(AutomationIds.rateModal);
// "~Cancel" is a content-desc match on Android, where Flutter puts the button
// label in content-desc, so it still applies; the predicates are iOS-only.
const rateDismissSelectors = () => forPlatform([
  byId(AutomationIds.rateDismiss),
  "~Cancel",
  "~Avbryt",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (label CONTAINS[c] 'Cancel' OR name CONTAINS[c] 'Cancel')",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (label CONTAINS[c] 'Avbryt' OR name CONTAINS[c] 'Avbryt')"
]);

// The Safari "Want to block video ads?" sheet (safari_onboard_yt_sheet.dart)
// shows once after DNS is enabled until the user taps "Skip for now", which
// persists. A wiped/re-prepared phone shows it again and it covers Home.
const safariOnboardSkipLabels = ["Skip for now", "Hoppa över för nu", "Pomiń na razie"];
const safariOnboardSkipSelectors = () =>
  safariOnboardSkipLabels.flatMap((label) => [
    `~${label}`,
    `-ios predicate string: label == '${label}' OR name == '${label}'`
  ]);

export async function dismissSafariOnboardIfPresent(): Promise<boolean> {
  for (const selector of forPlatform(safariOnboardSkipSelectors())) {
    try {
      const button = await $(selector);
      if (await button.isExisting()) {
        await tap(button);
        await driver.pause(800);
        console.warn(`Safari onboarding sheet dismissed via selector '${selector}'.`);
        return true;
      }
    } catch (error) {
      console.warn(`Safari onboarding skip selector '${selector}' failed: ${String(error)}`);
    }
  }
  return false;
}

let lastDismissAttempt = 0;

async function findAnyRateElement(): Promise<WebdriverIO.Element | undefined> {
  const selectors = [rateModalSelector(), byId(AutomationIds.rateDismiss), ...rateDismissSelectors()];
  for (const selector of selectors) {
    try {
      const element = await $(selector);
      if (await element.isExisting()) {
        return element;
      }
    } catch (_) {
      // ignore lookup failures
    }
  }
  return undefined;
}

export async function dismissRatePromptIfPresent(timeout = 1000): Promise<boolean> {
  const now = Date.now();
  if (now - lastDismissAttempt < 1000) {
    return false;
  }
  lastDismissAttempt = now;

  const end = now + timeout;
  let rateElement = await findAnyRateElement();
  while (!rateElement && Date.now() < end) {
    await driver.pause(200);
    rateElement = await findAnyRateElement();
  }

  if (!rateElement) {
    return false;
  }

  console.warn("Rate prompt detected, attempting dismissal.");

  for (const selector of rateDismissSelectors()) {
    try {
      const button = await $(selector);
      if (await button.isExisting()) {
        await tap(button);
        await driver.pause(500);
        const stillPresent = await findAnyRateElement();
        if (!stillPresent) {
          console.warn(`Rate prompt dismissed via selector '${selector}'.`);
          return true;
        }
      }
    } catch (error) {
      console.warn(`Rate prompt dismiss selector '${selector}' failed: ${String(error)}`);
    }
  }

  console.warn("Rate prompt detected but could not be dismissed automatically.");
  return false;
}
