import { $, driver } from "@wdio/globals";

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
import { compareToGolden } from "../../support/golden.js";

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

    // Adapty settles the presented view (start.dart sleeps ~3s for non-freemium).
    await driver.pause(4000);
    await saveScreenshot("paywall.png");
    await compareToGolden("paywall.png", { maskTopRatio: 0.06 });
  });

  after(async () => {
    // Dismiss the native Adapty modal we presented so the device is not left
    // covered for the next spec / manual use. Relaunch is the reliable way to
    // close a native modal (activateApp cannot).
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID).catch(() => undefined);
  });
});
