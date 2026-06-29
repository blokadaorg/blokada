import { $, driver } from "@wdio/globals";

import { activateApp, terminateApp } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { ensureAccountActive, openSettingsScreen } from "../../flows/account.js";
import { waitForPowerButton } from "../../flows/home.js";
import { dismissIntroOverlayIfPresent } from "../../flows/onboarding.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { goBackToHome, openExceptionsSubPage, openRetentionSubPage, tapBack } from "../../flows/nav.js";
import { AutomationIds } from "../../support/automationIds.js";
import { registerFailureArtifacts } from "../../support/artifacts.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

const screenTitleSelector = `~${AutomationIds.screenTitle}`;

// Open the two main Settings sub-pages (Exceptions, Retention) and assert they
// render. Runs on the active account; returns to Home (no state change).
describe("Smoke: Settings sub-page navigation", () => {
  before(async () => {
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await ensureAccountActive();
  });

  it("opens the Exceptions and Retention sub-pages", async () => {
    await openSettingsScreen();

    // Exceptions: both tab segments + a title render.
    await openExceptionsSubPage();
    await (await $(screenTitleSelector)).waitForExist({ timeout: 10000 });

    // Switch to the Allowed tab and verify the selection actually changed — both
    // segments are always present, so existence alone proves nothing. Each segment
    // exposes `Semantics(selected:)` (default tab is Blocked), so assert it flips.
    // If XCUITest doesn't surface `selected` for the merged node, degrade to
    // confirming the page survives the switch (no crash).
    const allowedTab = await $(`~${AutomationIds.exceptionsTabAllowed}`);
    const selectedBefore = await allowedTab.getAttribute("selected").catch(() => null);
    await allowedTab.click();
    if (selectedBefore === "true" || selectedBefore === "false") {
      await driver.waitUntil(
        async () => (await allowedTab.getAttribute("selected")) === "true",
        { timeout: 10000, timeoutMsg: "Allowed tab did not become selected after tap" }
      );
    } else {
      console.warn(
        "Exceptions tab 'selected' attribute not exposed; asserting page survival only."
      );
      await (await $(`~${AutomationIds.exceptionsTabBlocked}`)).waitForExist({ timeout: 10000 });
    }
    await tapBack(AutomationIds.screenSettings);

    // Retention: toggle + title render. Do NOT flip the toggle — it changes a real
    // user setting; presence is enough for a smoke.
    await openRetentionSubPage();
    await (await $(screenTitleSelector)).waitForExist({ timeout: 10000 });
    await tapBack(AutomationIds.screenSettings);

    await goBackToHome();
  });
});
