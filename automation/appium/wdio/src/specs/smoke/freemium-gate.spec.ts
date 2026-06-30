import { $, driver } from "@wdio/globals";

import { activateApp, terminateApp } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { ensureAccountInactive } from "../../flows/account.js";
import { waitForPowerButton } from "../../flows/home.js";
import { dismissIntroOverlayIfPresent } from "../../flows/onboarding.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { goBackToHome, openHubScreen } from "../../flows/nav.js";
import { AutomationIds } from "../../support/automationIds.js";
import { registerFailureArtifacts } from "../../support/artifacts.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

// On a libre (freemium) account the Advanced blocklists are gated behind an upgrade
// overlay (FreemiumScreen). Assert that gate renders — a revenue-relevant regression
// guard. Reuses the paywall spec's inactive account (no extra restore); returns Home.
describe("Smoke: freemium gate on Advanced", () => {
  before(async () => {
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await ensureAccountInactive();
  });

  it("shows the upgrade gate over the blocklists", async () => {
    await openHubScreen(AutomationIds.homeAdvanced, AutomationIds.screenAdvanced);

    const cta = await $(`~${AutomationIds.freemiumCta}`);
    await cta.waitForExist({ timeout: 15000 });
    await driver.waitUntil(async () => cta.isDisplayed().catch(() => false), {
      timeout: 10000,
      timeoutMsg: "Freemium upgrade CTA exists but is not displayed on Advanced."
    });

    await goBackToHome();
  });
});
