import { driver } from "@wdio/globals";
import { expect } from "chai";

import { enablePrivateDnsFromSheet, waitForPrivateDnsSheet } from "../../flows/android-dns.js";
import { activateApp, terminateApp } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { ensureAccountActive } from "../../flows/account.js";
import { getProtectionState, tapPowerButton, waitForPowerButton } from "../../flows/home.js";
import { dismissIntroOverlayIfPresent } from "../../flows/onboarding.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { registerFailureArtifacts, setSensitiveScreen } from "../../support/artifacts.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "org.blokada.sex";

/**
 * Tap power until the Private DNS sheet shows. Right after launch the button
 * reads "Please wait..." and ignores taps, so a single tap can be dropped.
 */
async function tapPowerUntilSheet(timeout = 30000): Promise<void> {
  await driver.waitUntil(
    async () => {
      await tapPowerButton();
      return waitForPrivateDnsSheet(4000);
    },
    {
      timeout,
      interval: 1000,
      timeoutMsg: "Private DNS onboarding sheet did not appear after tapping power"
    }
  );
}

// Android counterpart of dns-onboarding.spec: turns protection on for the
// active (Cloud) account through system Private DNS. The harness resets Private
// DNS before the run (wdio.android.conf.ts), so activation always starts from
// the onboarding sheet. Leaves protection ON for the specs that follow.
describe("Smoke: Android protection via Private DNS", () => {
  before(async () => {
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await ensureAccountActive();
  });

  after(() => setSensitiveScreen(false));

  it("enables protection through the Private DNS sheet", async () => {
    await waitForPowerButton();
    expect(await getProtectionState(), "protection should start off").to.equal("inactive");

    // The sheet and Settings show the hostname, which carries the device tag,
    // and CI uploads screenshots from a public repo: no capture until it's gone.
    // On failure it stays set through the failure capture; `after` clears it.
    setSensitiveScreen(true);
    await tapPowerUntilSheet();
    const pickedUpBy = await enablePrivateDnsFromSheet(APP_BUNDLE_ID);
    setSensitiveScreen(false);
    console.warn(`Private DNS change picked up by the app on ${pickedUpBy}.`);

    // The app asks for a rating right after the first activation.
    await dismissRatePromptIfPresent(8000);
    expect(await getProtectionState()).to.equal("active");
  });
});
