import { $, driver } from "@wdio/globals";

import { AutomationIds } from "../support/automationIds.js";
import { readCurrentAccount, writeCurrentAccount } from "../support/account-state.js";
import { activateApp, terminateApp } from "./app.js";
import { acceptNotificationAlert } from "./alerts.js";
import { waitForPowerButton } from "./home.js";
import { dismissRatePromptIfPresent } from "./modals.js";
import { dismissIntroOverlayIfPresent } from "./onboarding.js";

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

const homeSettingsSelector = `~${AutomationIds.homeSettings}`;
const settingsScreenSelector = `~${AutomationIds.screenSettings}`;
const supportRowSelector = `~${AutomationIds.settingsSupport}`;

// The support-chat composer comes from the third-party `flutter_chat_ui`
// package and carries no automation ids, so we locate it structurally: the
// chat screen has exactly one text input.
const chatInputSelector =
  "-ios predicate string: type == 'XCUIElementTypeTextField' OR type == 'XCUIElementTypeTextView'";
const chatSendLabelSelectors = [
  "~Send",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (label CONTAINS[c] 'Send' OR name CONTAINS[c] 'Send')"
];

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
  const gear = await $(homeSettingsSelector);
  await gear.waitForExist({ timeout });
  await gear.click();
  await (await $(settingsScreenSelector)).waitForExist({ timeout });
}

/** Navigate Home -> Settings -> Support chat and wait for the composer input. */
export async function openSupportChat(timeout = 15000): Promise<void> {
  await openSettingsScreen(timeout);
  const row = await $(supportRowSelector);
  await row.waitForExist({ timeout });
  await row.click();
  await (await $(chatInputSelector)).waitForExist({ timeout });
}

async function tapChatSend(): Promise<void> {
  // The send IconButton (Icons.send) has no label; try a label match first,
  // then fall back to tapping the far-right of the composer row (the send
  // button sits to the right of the input). Device geometry is fixed in CI.
  for (const selector of chatSendLabelSelectors) {
    try {
      const button = await $(selector);
      if (await button.isExisting()) {
        await button.click();
        return;
      }
    } catch {
      // try the next selector
    }
  }

  const input = await $(chatInputSelector);
  const location = await input.getLocation();
  const size = await input.getSize();
  const rect = await driver.getWindowRect();
  await driver.execute("mobile: tap", {
    x: Math.round(rect.width - 28),
    y: Math.round(location.y + size.height / 2)
  });
}

/**
 * Drive the support chat to run a command through the app command bus. Any
 * message prefixed `cc ` is routed to `command.onCommandString`, so this is a
 * generic injection point (e.g. `restore <id>`, `route home`). Must be called
 * from the Home screen.
 */
export async function sendChatCommand(command: string): Promise<void> {
  await dismissRatePromptIfPresent(2000);
  await openSupportChat();

  const input = await $(chatInputSelector);
  await input.waitForExist({ timeout: 10000 });
  await input.click();
  try {
    await input.clearValue();
  } catch {
    // field may already be empty / not clearable — ignore
  }
  await input.setValue(`cc ${command}`);
  await tapChatSend();

  // The return key inserts a newline rather than submitting, so the tap above
  // is the only submit path. Brief settle for the user bubble to echo; callers
  // that need command completion (see restoreAccount) wait on a real signal.
  await driver.pause(1000);
}

/**
 * Switch the active account by id via `cc restore <id>`, then relaunch to a
 * clean Home. Relaunch is deterministic regardless of the restore branch
 * (active restore reroutes to Settings; inactive stays on the chat screen).
 */
export async function restoreAccount(accountId: string): Promise<void> {
  await sendChatCommand(`restore ${accountId}`);

  // Wait for the restore to complete before relaunching, so a slow network
  // restore is not killed mid-persist. An active restore reroutes to the
  // Settings screen only after the account API call + persist, which is a
  // reliable, history-proof completion signal. An inactive restore stays on the
  // chat with no nav and no dependable UI signal (the "OK" reply bubble can be
  // a stale message from a prior run's persisted chat history), so fall back to
  // a fixed settle covering the network round trip.
  const rerouted = await driver
    .waitUntil(async () => await elementExists(settingsScreenSelector), {
      timeout: 8000,
      interval: 400
    })
    .then(() => true)
    .catch(() => false);
  if (!rerouted) {
    await driver.pause(4000);
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
  await restoreAccount(active);
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
        if (!(await elementExists(`~${AutomationIds.powerToggle}`))) {
          return false;
        }
        const value = await (await $(`~${AutomationIds.powerToggle}`)).getAttribute("value");
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
