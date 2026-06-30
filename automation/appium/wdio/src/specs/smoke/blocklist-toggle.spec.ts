import { $, driver } from "@wdio/globals";
import { expect } from "chai";

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

// Filter option switches expose ids like `automation.filter_option.<filter>.<option>`
// (filter.dart `_filterOptionAutomationId`) with the CupertinoSwitch state on the
// element `value` ("1"/"0"). Match any of them by id prefix so the spec isn't pinned
// to one pack name (which varies by account/flavor); the first match is then pinned
// by its exact id so a list rebuild on toggle can't retarget a different option.
const filterOptionPrefixSelector =
  "-ios predicate string: name BEGINSWITH 'automation.filter_option.'";

// The filter actor debounces the backend write ~1s then syncs; give margin before
// asserting the new state and before toggling back so each write commits.
const SYNC_WAIT_MS = 2000;

async function valueOf(selector: string): Promise<string | undefined> {
  const value = await (await $(selector)).getAttribute("value");
  return typeof value === "string" ? value : undefined;
}

// Exercises the core blocking config: enable/disable a filter option, confirm the
// switch state flips, then restore it so the account's config is left unchanged.
// Requires the paid/active account — freemium wraps the filter list in IgnorePointer
// so toggles are inert. Runs on the active account; returns Home (protection
// untouched).
describe("Smoke: blocklist pack toggle", () => {
  before(async () => {
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await ensureAccountActive();
  });

  it("toggles a filter option and restores it", async () => {
    await openHubScreen(AutomationIds.homeAdvanced, AutomationIds.screenAdvanced);

    // First available filter option. Fail loudly if none render (wrong account type
    // or the Advanced list failed to populate).
    const firstOption = await $(filterOptionPrefixSelector);
    await firstOption.waitForExist({ timeout: 15000 });
    const optionId = await firstOption.getAttribute("name");
    expect(optionId, "filter option should expose its automation id")
      .to.be.a("string")
      .and.match(/^automation\.filter_option\./);
    const optionSelector = `~${optionId}`;

    const initial = await valueOf(optionSelector);
    expect(initial, "filter option should expose a switch value").to.be.a("string");

    // Flip it and confirm the switch state changed (optimistic UI update).
    await (await $(optionSelector)).click();
    await driver.pause(SYNC_WAIT_MS);
    await driver.waitUntil(async () => (await valueOf(optionSelector)) !== initial, {
      timeout: 10000,
      interval: 500,
      timeoutMsg: `Filter option '${String(optionId)}' value did not change from '${String(
        initial
      )}' after toggling.`
    });

    // Restore the original state so the spec leaves the account's config unchanged.
    await (await $(optionSelector)).click();
    await driver.pause(SYNC_WAIT_MS);
    await driver.waitUntil(async () => (await valueOf(optionSelector)) === initial, {
      timeout: 10000,
      interval: 500,
      timeoutMsg: `Filter option '${String(optionId)}' did not return to its original state '${String(
        initial
      )}'.`
    });

    await goBackToHome();
  });
});
