import { $, $$, driver } from "@wdio/globals";

import { activateApp, terminateApp } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { ensureAccountInactive } from "../../flows/account.js";
import {
  getProtectionState,
  tapPowerButton,
  waitForPowerButton,
  waitForProtectionInactive
} from "../../flows/home.js";
import { dismissIntroOverlayIfPresent } from "../../flows/onboarding.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { AutomationIds } from "../../support/automationIds.js";
import { registerFailureArtifacts, saveScreenshot } from "../../support/artifacts.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

const powerToggleSelector = `~${AutomationIds.powerToggle}`;
const pauseSheetSelector = `~${AutomationIds.powerActionSheet}`;
const dnsSheetSelector = `~${AutomationIds.dnsOnboardingSheet}`;
// Adapty's paywall is dashboard-configured and carries no automation ids, so
// the positive signal is a price/CTA control appearing over the home screen.
const paywallCtaSelector =
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (" +
  "label CONTAINS[c] 'Continue' OR label CONTAINS[c] 'Subscribe' OR " +
  "label CONTAINS[c] 'Restore' OR label CONTAINS[c] 'Start' OR " +
  "label CONTAINS[c] 'Try' OR label CONTAINS '$' OR label CONTAINS '€' OR " +
  "label CONTAINS '£')";

// Checks for the settled paywall. They read what any Blokada paywall has to
// offer (priced plans, a buy button, restore) rather than how it looks: the
// paywall is a Flow Builder flow edited in the Adapty dashboard, and its
// carousel rotates on its own, so a pixel baseline breaks on every design
// change and on timing.
const planSelector =
  "-ios predicate string: type == 'XCUIElementTypeButton' AND " +
  "(label CONTAINS[c] 'per year' OR label CONTAINS[c] 'per month')";
const buyButtonSelector =
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (" +
  "label BEGINSWITH[c] 'Subscribe' OR label BEGINSWITH[c] 'Start' OR " +
  "label BEGINSWITH[c] 'Try' OR label BEGINSWITH[c] 'Continue')";
const restoreSelector =
  "-ios predicate string: type == 'XCUIElementTypeButton' AND label ==[c] 'Restore'";
// The close X is an icon with no label; it is the only unlabelled button in
// the top corner of the paywall.
const unlabelledButtonSelector =
  "-ios predicate string: type == 'XCUIElementTypeButton' AND label == '' AND visible == 1";

async function exists(selector: string): Promise<boolean> {
  try {
    return await (await $(selector)).isExisting();
  } catch {
    return false;
  }
}

/**
 * Wait until the native Adapty paywall is presented after tapping power on an
 * inactive account. Fails fast with a specific message if the account turns out
 * not to be inactive/libre (protection activated, pause sheet, or DNS onboarding
 * appeared instead).
 */
async function waitForPaywall(timeout = 20000): Promise<void> {
  const end = Date.now() + timeout;
  let toggleHiddenStreak = 0;
  while (Date.now() < end) {
    if (await exists(pauseSheetSelector)) {
      throw new Error(
        "Pause action sheet appeared instead of the paywall — account is " +
          "active with protection ON, not inactive."
      );
    }
    if (await exists(dnsSheetSelector)) {
      throw new Error(
        "DNS onboarding sheet appeared instead of the paywall — account is " +
          "active (DNS not provisioned), not inactive."
      );
    }
    // Strong signal: a price / CTA control from the paywall is present.
    if (await exists(paywallCtaSelector)) {
      return;
    }

    const toggle = await $(powerToggleSelector);
    const toggleVisible = (await toggle.isExisting()) && (await toggle.isDisplayed());
    if (!toggleVisible) {
      // Weaker signal: home is covered. Require it to persist across two checks
      // so a transient frame during the tap transition is not mistaken for the
      // paywall.
      toggleHiddenStreak += 1;
      if (toggleHiddenStreak >= 2) {
        return;
      }
    } else {
      toggleHiddenStreak = 0;
      const value = (await toggle.getAttribute("value"))?.toLowerCase();
      if (value === "active") {
        throw new Error(
          "Protection activated instead of showing the paywall — account is " +
            "active, not inactive."
        );
      }
    }

    await driver.pause(500);
  }
  throw new Error(
    "Paywall did not appear within timeout (home screen never got covered and " +
      "no paywall control was found)."
  );
}

async function waitForSettledPaywall(timeout = 20000): Promise<void> {
  let missing = "";
  try {
    await driver.waitUntil(
      async () => {
        const plans = await $$(planSelector).length;
        if (plans < 2) {
          missing = `priced plans (found ${plans}, need 2)`;
          return false;
        }
        if (!(await exists(buyButtonSelector))) {
          missing = "the buy button";
          return false;
        }
        if (!(await exists(restoreSelector))) {
          missing = "the Restore link";
          return false;
        }
        return true;
      },
      { timeout, interval: 1000 }
    );
  } catch {
    throw new Error(`Paywall opened but never showed ${missing}.`);
  }
}

async function tapPaywallClose(): Promise<void> {
  const { height } = await driver.getWindowRect();
  for (const button of await $$(unlabelledButtonSelector)) {
    const { y } = await button.getLocation();
    if (y < height * 0.2) {
      await button.click();
      return;
    }
  }
  throw new Error("Paywall close button not found in the top of the screen.");
}

describe("Smoke: paywall on inactive account", () => {
  before(async () => {
    // Clean slate: relaunch closes any leftover Adapty modal from an
    // interrupted prior run and resets the Flutter route to Home.
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await ensureAccountInactive();
  });

  it("presents the native paywall when enabling protection", async () => {
    await waitForPowerButton();
    await waitForProtectionInactive();
    const startState = await getProtectionState();
    if (startState !== "inactive") {
      throw new Error(
        `Expected protection to be inactive before tapping power, got ` +
          `'${String(startState)}'.`
      );
    }

    await tapPowerButton();
    await waitForPaywall();

    await waitForSettledPaywall();
    await saveScreenshot("paywall.png");

    await tapPaywallClose();
    try {
      await driver.waitUntil(
        async () =>
          !(await exists(planSelector)) &&
          (await (await $(powerToggleSelector)).isDisplayed()),
        { timeout: 10000 }
      );
    } catch {
      throw new Error("Paywall stayed on screen after tapping close.");
    }
  });

  after(async () => {
    // Dismiss the native Adapty modal we presented so the device is not left
    // covered for the next spec / manual use. Relaunch is the reliable way to
    // close a native modal (activateApp cannot).
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID).catch(() => undefined);
  });
});
