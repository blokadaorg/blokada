import { $, $$, driver } from "@wdio/globals";

import { activateApp, terminateApp } from "../../flows/app.js";
import { acceptNotificationAlert } from "../../flows/alerts.js";
import { ensureAccountActive, openSettingsScreen } from "../../flows/account.js";
import { waitForPowerButton } from "../../flows/home.js";
import { dismissIntroOverlayIfPresent } from "../../flows/onboarding.js";
import { dismissRatePromptIfPresent } from "../../flows/modals.js";
import { goBackToHome, openExceptionsSubPage, tapBack } from "../../flows/nav.js";
import { AutomationIds } from "../../support/automationIds.js";
import { registerFailureArtifacts } from "../../support/artifacts.js";

registerFailureArtifacts();

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

const addButtonSelector = `~${AutomationIds.exceptionAddButton}`;
const domainInputSelector = `~${AutomationIds.exceptionDomainInput}`;
const saveButtonSelector = `~${AutomationIds.exceptionSaveButton}`;
const deleteSelector = `~${AutomationIds.exceptionDelete}`;

// Throwaway domain, unique per run so a leftover from an interrupted run can't
// collide (the spec deletes it either way). RFC-2606 reserved domain.
const testDomain = `smoke-${Date.now()}.example.com`;
// Match the domain with CONTAINS, not ==: the exception_item exposes its label as
// the domain twice (an explicit Semantics(label:) plus the child Text, merged with a
// newline), and long domains get middle-ellipsized in the visible Text.
const rowSelector =
  `-ios predicate string: name == '${AutomationIds.exceptionItem}' AND label CONTAINS '${testDomain}'`;

async function exists(selector: string): Promise<boolean> {
  try {
    return await (await $(selector)).isExisting();
  } catch {
    return false;
  }
}

// Custom allow/block exceptions are the core user-configurable rule surface and were
// untested. Add a blocked domain, confirm it lands in the Blocked list, then swipe-
// delete it — leaving the account's list unchanged. Active account; returns Home.
describe("Smoke: custom exception add / verify / delete", () => {
  before(async () => {
    await terminateApp(APP_BUNDLE_ID);
    await activateApp(APP_BUNDLE_ID);
    await dismissRatePromptIfPresent(5000);
    await acceptNotificationAlert();
    await dismissIntroOverlayIfPresent();
    await waitForPowerButton();
    await ensureAccountActive();
  });

  it("adds a blocked domain then removes it", async () => {
    await openSettingsScreen();
    await openExceptionsSubPage(); // opens on the Blocked tab

    // Add: tap the top-bar Add action, type the domain, Save. The dialog's default
    // segment is "Block", so the entry lands in the Blocked list. Use setValue (types
    // via XCUITest typeText) rather than driver.keys() — the latter sends low-level
    // key actions that WDA rejects when the string repeats a character ("Key Down ...
    // must have a closing Key Up successor").
    await (await $(addButtonSelector)).waitForExist({ timeout: 15000 });
    await (await $(addButtonSelector)).click();

    const input = await $(domainInputSelector);
    await input.waitForExist({ timeout: 10000 });
    await input.click();
    await input.setValue(testDomain);

    await (await $(saveButtonSelector)).click();

    // Verify: backend add + fetch is async, so poll for the new row in the list.
    await driver.waitUntil(() => exists(rowSelector), {
      timeout: 20000,
      interval: 1000,
      timeoutMsg: `Added exception '${testDomain}' did not appear in the Blocked list.`
    });

    // Delete: a row tap opens the domain detail, so swipe the row left to reveal its
    // end action pane, then tap the revealed delete. SlidableAutoCloseBehavior keeps
    // only one pane open, so the displayed delete is this row's.
    const row = await $(rowSelector);
    const loc = await row.getLocation();
    const size = await row.getSize();
    const midY = Math.round(loc.y + size.height / 2);
    await driver.execute("mobile: dragFromToForDuration", {
      duration: 0.5,
      fromX: Math.round(loc.x + size.width * 0.9),
      fromY: midY,
      toX: Math.round(loc.x + size.width * 0.1),
      toY: midY
    });

    await driver.waitUntil(
      async () => {
        for (const action of await $$(deleteSelector)) {
          if (await action.isDisplayed().catch(() => false)) {
            await action.click();
            return true;
          }
        }
        return false;
      },
      {
        timeout: 10000,
        interval: 500,
        timeoutMsg: "Delete action did not become tappable after the swipe."
      }
    );

    // Confirm cleanup: the row is gone (backend remove + fetch is async).
    await driver.waitUntil(async () => !(await exists(rowSelector)), {
      timeout: 20000,
      interval: 1000,
      timeoutMsg: `Exception '${testDomain}' was not removed.`
    });

    await tapBack(AutomationIds.screenSettings);
    await goBackToHome();
  });
});
