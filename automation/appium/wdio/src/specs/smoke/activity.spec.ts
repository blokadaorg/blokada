import { $ } from "@wdio/globals";

import { activateApp, terminateApp } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { ensureAccountActive } from "../../flows/account.js";
import { waitForPowerButton } from "../../flows/home.js";
import { dismissIntroOverlayIfPresent } from "../../flows/onboarding.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { goBackToHome, openHubScreen, tapBack, waitForScreen } from "../../flows/nav.js";
import { AutomationIds } from "../../support/automationIds.js";
import { registerFailureArtifacts } from "../../support/artifacts.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

// Reach the full Activity list via Privacy Pulse -> "Show All" — a route only made
// reachable-by-test after the V6 nav cleanup — and confirm it renders (top-bar title
// + screen body, catching route/blank/crash regressions). The search action and list
// rows are gated on activity retention, so they are best-effort signals, not hard
// assertions. Active account; returns Home.
describe("Smoke: Activity screen", () => {
  before(async () => {
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await ensureAccountActive();
  });

  it("opens the full Activity list from Privacy Pulse", async () => {
    await openHubScreen(AutomationIds.homePrivacyPulse, AutomationIds.screenPrivacyPulse);

    const showAll = await $(`~${AutomationIds.recentActivityShowAll}`);
    await showAll.waitForExist({ timeout: 15000 });
    await showAll.click();

    // The Activity screen body + top-bar title must render.
    await waitForScreen(AutomationIds.screenActivity);

    // Best-effort: the search action only renders when stats are shown (retention
    // enabled or freemium). Its presence confirms the stats-list path; absence just
    // means this account shows the "enable retention" prompt instead.
    const hasSearch = await (await $(`~${AutomationIds.activitySearch}`))
      .waitForExist({ timeout: 4000 })
      .then(() => true)
      .catch(() => false);
    if (!hasSearch) {
      console.warn(
        "Activity search action absent (retention likely disabled); screen still rendered."
      );
    }

    // Return: Activity (depth 2) -> Privacy Pulse (depth 1) -> Home.
    await tapBack(AutomationIds.screenPrivacyPulse);
    await goBackToHome();
  });
});
