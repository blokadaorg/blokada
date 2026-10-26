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
