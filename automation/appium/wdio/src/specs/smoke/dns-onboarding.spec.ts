import { driver } from "@wdio/globals";
import { expect } from "chai";

import { activateApp, switchToAppViaAppSwitcher } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { getProtectionState, tapPowerButton, waitForPowerButton, waitForProtectionActive, waitForProtectionInactive } from "../../flows/home.js";
import { dismissIntroOverlayIfPresent, openDnsSettingsFromSheet, waitForDnsOnboardingDismiss, waitForDnsOnboardingSheet } from "../../flows/onboarding.js";
import { enableDnsProfile, waitForSettingsForeground, SETTINGS_BUNDLE_ID } from "../../flows/settings.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { registerFailureArtifacts, saveScreenshot } from "../../support/artifacts.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";
const APP_DISPLAY_NAME =
  (process.env.APP_DISPLAY_NAME ?? process.env.APP_NAME ?? "").trim();

describe("Smoke: DNS onboarding flow", () => {
  it("enables protection after provisioning DNS permissions", async () => {
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await waitForProtectionInactive();

    await tapPowerButton();

    let onboardingNeeded = false;
    try {
      await waitForDnsOnboardingSheet();
      onboardingNeeded = true;
    } catch (error) {
      console.warn(`DNS onboarding sheet not shown, assuming profile already provisioned: ${String(error)}`);
    }

    if (onboardingNeeded) {
      await saveScreenshot("dns-onboarding-before-settings.png");

      await acceptNotificationAlert();
      await openDnsSettingsFromSheet();
      await waitForSettingsForeground();
      await enableDnsProfile();
      await waitForSettingsForeground();

      // Ensure Settings stays active until we explicitly return.
      const settingsState = await driver.execute("mobile: queryAppState", {
        bundleId: SETTINGS_BUNDLE_ID
      });
      expect(settingsState).to.equal(
        4,
        "Settings should remain in foreground before switching back to Blokada"
      );
    }

    await switchToAppViaAppSwitcher(APP_BUNDLE_ID, APP_DISPLAY_NAME);
    await dismissRatePromptIfPresent(5000);
    await dismissIntroOverlayIfPresent();
    await waitForDnsOnboardingDismiss();
    await waitForPowerButton();
    const currentState = await getProtectionState();
    if (currentState !== "active") {
      await tapPowerButton();
    }
    await waitForProtectionActive(30000);
    await dismissRatePromptIfPresent(5000);
    await saveScreenshot("dns-onboarding-active.png");
  });
});
