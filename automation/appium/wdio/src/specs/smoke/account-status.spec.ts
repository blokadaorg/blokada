import { $ } from "@wdio/globals";
import { expect } from "chai";

import { activateApp, terminateApp } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { ensureAccountActive, openSettingsScreen } from "../../flows/account.js";
import { waitForPowerButton } from "../../flows/home.js";
import { dismissIntroOverlayIfPresent } from "../../flows/onboarding.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { goBackToHome } from "../../flows/nav.js";
import { AutomationIds } from "../../support/automationIds.js";
import { registerFailureArtifacts } from "../../support/artifacts.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

// The Settings account header shows subscription status. For the active account it
// reads "<type>, expires <YYYY-MM-DD>"; an inactive account reads a plain "inactive"
// string with no date. Assert the status carries a year — i.e. the account is
// recognized as subscribed. Active account; returns Home.
describe("Smoke: account shows active subscription", () => {
  before(async () => {
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await ensureAccountActive();
  });

  it("renders an active subscription status", async () => {
    await openSettingsScreen();

    const status = await $(`~${AutomationIds.settingsAccountStatus}`);
    await status.waitForExist({ timeout: 15000 });
    const label = await status.getAttribute("label");
    expect(label, "account status label should be a string").to.be.a("string");
    expect(
      label,
      `account status '${String(label)}' should show a subscription expiry year`
    ).to.match(/\d{4}/);

    await goBackToHome();
  });
});
