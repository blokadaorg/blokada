import { $, driver } from "@wdio/globals";
import { expect } from "chai";

import { activateApp, terminateApp } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { ensureAccountActive } from "../../flows/account.js";
import {
  cancelActionSheetIfPresent,
  getProtectionState,
  tapPowerButton,
  tapTurnOff,
  waitForPauseActionSheet,
  waitForPowerButton,
  waitForProtectionInactive
} from "../../flows/home.js";
import { dismissIntroOverlayIfPresent } from "../../flows/onboarding.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { AutomationIds } from "../../support/automationIds.js";
import { registerFailureArtifacts, saveScreenshot } from "../../support/artifacts.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";
const dnsSheetSelector = `~${AutomationIds.dnsOnboardingSheet}`;

/**
 * Tap power until protection reports active. The toggle reads "inactive" the
 * instant status enters `reconfiguring` (still working), and the power button
 * ignores taps while working — so a single tap can be silently dropped. Retry
 * until it sticks. The guard checks active before each tap, so we never tap while
 * active (which would open the pause sheet instead of toggling on); a tap landing
 * during `reconfiguring` is a harmless no-op.
 */
async function activateUntilOn(timeout = 30000): Promise<void> {
  await driver.waitUntil(
    async () => {
      if ((await getProtectionState()) === "active") {
        return true;
      }
      await tapPowerButton();
      return false;
    },
    {
      timeout,
      interval: 3000,
      timeoutMsg: "Protection did not return to active in time"
    }
  );
  // A retry tap can land in the brief window where status just became active,
  // opening the pause sheet instead of toggling on; dismiss any such stray sheet
  // so we never leave a modal open (Cancel does not change protection state).
  await cancelActionSheetIfPresent();
}

/**
 * Ensure protection is ON. The DNS profile is installed by dns-onboarding.spec
 * earlier in the run, so activation is a quick toggle with no onboarding sheet.
 * If the sheet appears, this spec ran before the DNS profile existed (out of
 * order) — fail loudly rather than drive the iOS Settings flow here.
 */
async function ensureProtectionActive(): Promise<void> {
  if ((await getProtectionState()) === "active") {
    return;
  }
  await tapPowerButton();
  const onboardingShown = await (await $(dnsSheetSelector))
    .waitForExist({ timeout: 4000 })
    .then(() => true)
    .catch(() => false);
  if (onboardingShown) {
    throw new Error(
      "DNS onboarding sheet appeared while activating — run power-pause.spec " +
        "after dns-onboarding.spec so the DNS profile is already installed."
    );
  }
  await activateUntilOn(30000);
}

// Completes the activation lifecycle: turning protection OFF via the pause action
// sheet. Requires a paid (non-freemium) active account — a freemium tap toggles
// off directly with no sheet. Restores protection ON at the end (suite resting
// state). Registered last in wdio.conf.ts.
describe("Smoke: power pause / turn-off", () => {
  before(async () => {
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await ensureAccountActive();
  });

  it("shows the pause sheet, turns protection off, then restores it", async () => {
    await waitForPowerButton();
    await ensureProtectionActive();

    // Tapping power while active on a non-freemium account opens the pause sheet.
    await tapPowerButton();
    await waitForPauseActionSheet();
    await saveScreenshot("power-pause-sheet.png");

    // Turn off; the toggle value must flip to inactive.
    await tapTurnOff();
    await waitForProtectionInactive(20000);
    expect(await getProtectionState()).to.equal("inactive");

    // Restore the suite's resting state: protection back ON. Use the retry helper
    // because the turn-off teardown leaves status in `reconfiguring` briefly,
    // during which a single re-activation tap would be dropped.
    await activateUntilOn(30000);
  });
});
