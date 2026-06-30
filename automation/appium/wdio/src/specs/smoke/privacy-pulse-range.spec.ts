import { $, driver } from "@wdio/globals";

import { activateApp, terminateApp } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { ensureAccountActive } from "../../flows/account.js";
import { waitForPowerButton } from "../../flows/home.js";
import { dismissIntroOverlayIfPresent } from "../../flows/onboarding.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { goBackToHome, openHubScreen } from "../../flows/nav.js";
import { AutomationIds } from "../../support/automationIds.js";
import { registerFailureArtifacts } from "../../support/artifacts.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";
const dailySelector = `~${AutomationIds.privacyPulseRangeDaily}`;
const weeklySelector = `~${AutomationIds.privacyPulseRangeWeekly}`;

// Opens Privacy Pulse and flips the 24h <-> 7d toplist range — the one interactive
// stats control, which tab-navigation only ever opens. The segments expose
// Semantics(selected:), so assert the selection moves (default is 24h); degrade to
// page-survival if XCUITest doesn't surface `selected` on the merged node (same
// pattern as the Exceptions tab switch). The range toggle renders unconditionally
// (it is the charts' trailing control). Active account; restores 24h and returns
// Home.
describe("Smoke: Privacy Pulse range toggle", () => {
  before(async () => {
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await ensureAccountActive();
  });

  it("switches between the 24h and 7d ranges", async () => {
    await openHubScreen(AutomationIds.homePrivacyPulse, AutomationIds.screenPrivacyPulse);

    const weekly = await $(weeklySelector);
    await weekly.waitForExist({ timeout: 15000 });

    // Default range is 24h, so the 7d segment should not be selected yet. Both
    // segments are always present, so existence proves nothing — assert the
    // selection flips. If the merged node doesn't expose `selected`, fall back to
    // confirming the page survives the switch.
    const exposesSelected = await weekly
      .getAttribute("selected")
      .then((v) => v === "true" || v === "false")
      .catch(() => false);

    await weekly.click();
    if (exposesSelected) {
      await driver.waitUntil(async () => (await weekly.getAttribute("selected")) === "true", {
        timeout: 10000,
        timeoutMsg: "7d range did not become selected after tapping it"
      });
    } else {
      console.warn(
        "Privacy Pulse range 'selected' attribute not exposed; asserting page survival only."
      );
      await (await $(dailySelector)).waitForExist({ timeout: 10000 });
    }

    // Restore the default 24h range.
    const daily = await $(dailySelector);
    await daily.waitForExist({ timeout: 10000 });
    await daily.click();
    if (exposesSelected) {
      await driver.waitUntil(async () => (await daily.getAttribute("selected")) === "true", {
        timeout: 10000,
        timeoutMsg: "24h range did not become selected after the restore tap"
      });
    }

    await goBackToHome();
  });
});
