import { activateApp, terminateApp } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { waitForPowerButton } from "../../flows/home.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { dismissIntroOverlayIfPresent } from "../../flows/onboarding.js";
import { registerFailureArtifacts } from "../../support/artifacts.js";
import { assertAdaptyFallbackHealthy } from "../../flows/adapty.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

describe("Smoke: Adapty fallback paywalls", () => {
  it("bundled fallback JSON is not rejected by the Adapty SDK on cold start", async () => {
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();

    await assertAdaptyFallbackHealthy(APP_BUNDLE_ID);
  });
});
