import { activateApp, terminateApp } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { ensureAccountActive } from "../../flows/account.js";
import { waitForPowerButton } from "../../flows/home.js";
import { dismissIntroOverlayIfPresent } from "../../flows/onboarding.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { goBackToHome, openHubScreen, waitForScreen } from "../../flows/nav.js";
import { AutomationIds } from "../../support/automationIds.js";
import { registerFailureArtifacts } from "../../support/artifacts.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

// V6 navigation is hub-and-spoke off Home: there is no bottom tab bar. Each main
// screen is opened from Home and popped back via the top-bar back control. Catches
// route/blank-screen/crash regressions cheaply; runs on the active account and
// leaves protection unchanged.
describe("Smoke: Home hub navigation", () => {
  before(async () => {
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await ensureAccountActive();
  });

  it("opens each main screen from Home and returns", async () => {
    // Home has no top bar / title.
    await waitForScreen(AutomationIds.screenHome, { withTitle: false });

    await openHubScreen(AutomationIds.homePrivacyPulse, AutomationIds.screenPrivacyPulse);
    await goBackToHome();

    await openHubScreen(AutomationIds.homeAdvanced, AutomationIds.screenAdvanced);
    await goBackToHome();

    await openHubScreen(AutomationIds.homeSettings, AutomationIds.screenSettings);
    await goBackToHome();
  });
});
