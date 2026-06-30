import { $, driver } from "@wdio/globals";
import { expect } from "chai";

import { activateApp, terminateApp } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { ensureAccountActive } from "../../flows/account.js";
import {
  cancelActionSheetIfPresent,
  getProtectionState,
  tapPowerButton,
  waitForPowerButton
} from "../../flows/home.js";
import { dismissIntroOverlayIfPresent } from "../../flows/onboarding.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { AutomationIds } from "../../support/automationIds.js";
import { registerFailureArtifacts } from "../../support/artifacts.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";
const dnsSheetSelector = `~${AutomationIds.dnsOnboardingSheet}`;

async function exists(selector: string): Promise<boolean> {
  try {
    return await (await $(selector)).isExisting();
  } catch {
    return false;
  }
}

/**
 * Drive protection to active and keep it there. Mirrors power-pause's helper: the
 * toggle reads "inactive" while status is reconfiguring and ignores taps while
 * working, so a single tap can be silently dropped — retry until it sticks. A retry
 * tap landing just as status turns active opens the pause sheet; cancel it.
 *
 * If activating raises the DNS onboarding sheet the DNS profile isn't installed —
 * fail loudly (this spec must run after dns-onboarding.spec).
 */
async function ensureProtectionActive(timeout = 30000): Promise<void> {
  await driver.waitUntil(
    async () => {
      if ((await getProtectionState()) === "active") {
        return true;
      }
      await tapPowerButton();
      if (await exists(dnsSheetSelector)) {
        throw new Error(
          "DNS onboarding sheet appeared while activating — run " +
            "cold-restart-persistence.spec after dns-onboarding.spec so the DNS " +
            "profile is already installed."
        );
      }
      return false;
    },
    { timeout, interval: 3000, timeoutMsg: "Protection did not reach active in time" }
  );
  await cancelActionSheetIfPresent();
}

// Protection must survive a cold app restart. Every other active spec re-activates
// if needed and so would mask a state-restoration regression; this one asserts the
// toggle is STILL active after a kill + relaunch, without tapping. Runs on the
// active account and leaves protection ON (suite resting state preserved).
describe("Smoke: protection persists across cold restart", () => {
  before(async () => {
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await ensureAccountActive();
  });

  it("stays active after a kill and relaunch", async () => {
    await waitForPowerButton();
    await ensureProtectionActive();
    expect(await getProtectionState()).to.equal("active");

    // Cold restart: fully terminate, then relaunch from scratch.
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();

    // Assert WITHOUT tapping: the app should restore the active tunnel on launch.
    // Allow a short settle while status resolves out of any transient reconfiguring
    // state; staying inactive is the regression this guards against.
    await driver.waitUntil(
      async () => (await getProtectionState()) === "active",
      {
        timeout: 20000,
        interval: 1000,
        timeoutMsg:
          "Protection did not report active after a cold restart — possible " +
          "state-restoration regression (it was active before the relaunch)."
      }
    );
    expect(await getProtectionState()).to.equal("active");
  });
});
