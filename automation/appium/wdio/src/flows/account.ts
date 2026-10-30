import { $, driver } from "@wdio/globals";

import { ANDROID_LAUNCH_ACTIVITY } from "../../scripts/lib/capabilities.mjs";
import { AutomationIds } from "../support/automationIds.js";
import { readCurrentAccount, writeCurrentAccount } from "../support/account-state.js";
import { byId, isAndroid, semanticValueOf, settleNavigation, tap } from "../support/platform.js";
import { activateApp, terminateApp, waitForAppForeground } from "./app.js";
import { acceptNotificationAlert } from "./alerts.js";
import { waitForPowerButton } from "./home.js";
import { dismissRatePromptIfPresent } from "./modals.js";
import { dismissIntroOverlayIfPresent } from "./onboarding.js";

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

const homeSettingsSelector = () => byId(AutomationIds.homeSettings);
const settingsScreenSelector = () => byId(AutomationIds.screenSettings);

export interface AccountIds {
  active: string;
  inactive: string;
}

function readRequiredEnv(name: string): string {
  const value = (process.env[name] ?? "").trim();
  if (!value) {
    throw new Error(
      `Missing required env ${name}. Set it (CI: GitHub secret ${name}) to a ` +
        `valid Blokada account id.`
    );
  }
  return value;
}

/** Account ids from env; throws a clear, named error if a secret is missing. */
export function getAccountIds(): AccountIds {
  return {
    active: readRequiredEnv("BLOKADA_ACTIVE_ACCOUNT_ID"),
    inactive: readRequiredEnv("BLOKADA_INACTIVE_ACCOUNT_ID")
  };
}

async function elementExists(selector: string): Promise<boolean> {
  try {
    return await (await $(selector)).isExisting();
  } catch {
    return false;
  }
}

/** Navigate Home -> in-app Settings via the home gear (bottom-tab ids are unreliable). */
export async function openSettingsScreen(timeout = 15000): Promise<void> {
  const gear = await $(homeSettingsSelector());
  await gear.waitForExist({ timeout });
  await tap(gear);
  await (await $(settingsScreenSelector())).waitForExist({ timeout });
  await settleNavigation();
}

/**
 * Cold-start the app with the debug restore launch argument: the
 * `restore_account_id` extra on Android, `-restoreAccountId` on iOS. Only
 * debug builds (Android) and the Dev schemes (iOS) read it.
 */
async function launchWithRestore(accountId: string): Promise<void> {
  await terminateApp(APP_BUNDLE_ID);
  if (isAndroid()) {
    const activity = process.env.ANDROID_APP_ACTIVITY ?? ANDROID_LAUNCH_ACTIVITY;
    await driver.execute("mobile: startActivity", {
      component: `${APP_BUNDLE_ID}/${activity}`,
      extras: [["s", "restore_account_id", accountId]],
      wait: true
    });
  } else {
    await driver.execute("mobile: launchApp", {
      bundleId: APP_BUNDLE_ID,
      arguments: ["-restoreAccountId", accountId]
    });
  }
  await waitForAppForeground(APP_BUNDLE_ID);
}

// The restore shows its result in a native dialog (Android AlertDialog, iOS
// alert). The dialog is modal for accessibility, so it hides the Flutter tree,
// Settings included, from Appium. Success and error dialogs differ only in
// localized text, so close whichever shows: an active restore has already
// rerouted to Settings underneath, a failed one has not.
const androidDialogClose = () => 'android=new UiSelector().resourceId("android:id/button1")';

async function closeResultDialog(): Promise<void> {
  if (isAndroid()) {
    if (await elementExists(androidDialogClose())) {
      await tap(await $(androidDialogClose()));
    }
    return;
  }
  try {
    // Throws when no app alert is open. The cancel-style button WebDriverAgent
    // dismisses with is "Close"; the other one would share the log.
    await driver.getAlertText();
    await driver.dismissAlert();
  } catch {
    // No alert.
  }
}

async function activeRestoreFinished(): Promise<boolean> {
  if (await elementExists(settingsScreenSelector())) return true;
  await closeResultDialog();
  return false;
}

/**
 * Switch the active account by id through the restore launch argument, then
 * relaunch to a clean Home. The relaunch carries no argument, so the restore
 * runs once. `expectActive` marks an account that is active: its restore
 * reroutes to Settings, and a restore that never finishes fails here instead
 * of being recorded as done.
 */
export async function restoreAccount(accountId: string, expectActive = false): Promise<void> {
  await launchWithRestore(accountId);

  // Wait for the restore to complete before relaunching, so a slow network
  // restore is not killed mid-persist.
  if (expectActive) {
    // An active restore reroutes to Settings and shows its result dialog only
    // after the account API call and persist. It still marks the intro seen
    // (or the intro returns on the next launch of a fresh install) and syncs
    // the account after that, so give those a moment too.
    const rerouted = await driver
      .waitUntil(activeRestoreFinished, { timeout: 30000, interval: 400 })
      .then(() => true)
      .catch(() => false);
    if (!rerouted) {
      // Name no id: CI uploads the output of a public repo.
      throw new Error(
        "Restoring the active account showed neither Settings nor its result: the restore failed, " +
          "or the installed build does not read the restore launch argument."
      );
    }
    await driver.pause(3000);
  } else {
    // An inactive restore has no navigation and only a localized result
    // dialog to show for it. The restore command runs once Flutter is up, so
    // wait for Home to render (best effort: the intro can cover it on a fresh
    // install), then settle for the account round trip.
    await driver
      .waitUntil(async () => await elementExists(homeSettingsSelector()), {
        timeout: 30000,
        interval: 400
      })
      .catch(() => undefined);
    await driver.pause(8000);
  }

  await terminateApp(APP_BUNDLE_ID);
  await activateApp(APP_BUNDLE_ID);
  await dismissRatePromptIfPresent(5000);
  await acceptNotificationAlert();
  await dismissIntroOverlayIfPresent();
  await waitForPowerButton();
}

/**
 * Ensure the device is on the active (paid) account. Restores only when the
 * device isn't already on it this run (see account-state.ts) — so when active
 * scenarios are grouped together the restore runs just once for the whole group.
 * Does NOT wait on the power toggle: an active account does not imply protection
 * is ON — the DNS spec turns protection on and that flow is the authoritative
 * active-account check.
 */
export async function ensureAccountActive(): Promise<void> {
  const { active } = getAccountIds();
  if (readCurrentAccount() === active) {
    console.warn(
      "ensureAccountActive: device already on the active account this run; skipping restore."
    );
    return;
  }
  await restoreAccount(active, true);
  writeCurrentAccount(active);
}

/**
 * Ensure the device is on the inactive (libre) account so the paywall appears
 * on the next power tap. Restores only when the device isn't already on it this
 * run (see account-state.ts). Switching to libre clears Plus, so protection
 * should switch off; we wait for that as a coarse sanity check, but the paywall
 * spec's tap-power assertion is the authoritative inactive check (the power
 * toggle's value reflects protection on/off, not account state).
 */
export async function ensureAccountInactive(): Promise<void> {
  const { inactive } = getAccountIds();
  if (readCurrentAccount() === inactive) {
    console.warn(
      "ensureAccountInactive: device already on the inactive account this run; skipping restore."
    );
    return;
  }
  await restoreAccount(inactive);
  writeCurrentAccount(inactive);
  // Best-effort settle: switching to libre clears Plus so protection should go
  // off, but the toggle value reflects protection (not account) state, so this
  // is only a coarse signal — never fail here. The paywall spec's tap-power
  // assertion is the authoritative inactive check.
  await driver
    .waitUntil(
      async () => {
        if (!(await elementExists(byId(AutomationIds.powerToggle)))) {
          return false;
        }
        const value = await semanticValueOf(await $(byId(AutomationIds.powerToggle)));
        return typeof value === "string" && value.toLowerCase() === "inactive";
      },
      { timeout: 15000, interval: 500 }
    )
    .catch(() => {
      console.warn(
        "ensureAccountInactive: protection still appears on after restore; " +
          "the paywall assertion will verify account state."
      );
    });
}
