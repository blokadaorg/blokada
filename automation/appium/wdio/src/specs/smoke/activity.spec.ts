import { $, driver } from "@wdio/globals";

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
const showAllSelector = `~${AutomationIds.recentActivityShowAll}`;

async function exists(selector: string): Promise<boolean> {
  try {
    return await (await $(selector)).isExisting();
  } catch {
    return false;
  }
}

// Privacy Pulse is a scrolling list and the Recent Activity section ("Show All")
// sits below the charts and top-domains, so it isn't in the tree until scrolled
// into view. Swipe up until it renders. (Swiping up scrolls content up; pull-to-
// refresh only triggers on a downward pull at the top, so this is safe.)
async function scrollToShowAll(maxSwipes = 8): Promise<boolean> {
  for (let i = 0; i < maxSwipes; i += 1) {
    if (await exists(showAllSelector)) return true;
    const rect = await driver.getWindowRect();
    const x = Math.round(rect.width / 2);
    await driver.execute("mobile: dragFromToForDuration", {
      duration: 0.4,
      fromX: x,
      fromY: Math.round(rect.height * 0.75),
      toX: x,
      toY: Math.round(rect.height * 0.3)
    });
    await driver.pause(400);
  }
  return exists(showAllSelector);
}

// Reach the full Activity list via Privacy Pulse -> "Show All" — a route only made
// reachable-by-test after the V6 nav cleanup — and confirm it renders (top-bar title
// + screen body, catching route/blank/crash regressions). The search action is gated
// on activity retention, so it is a best-effort signal, not a hard assertion. Active
// account; returns Home.
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

    if (!(await scrollToShowAll())) {
      throw new Error(
        "Recent Activity 'Show All' did not appear after scrolling the Privacy Pulse list."
      );
    }
    await (await $(showAllSelector)).click();

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
