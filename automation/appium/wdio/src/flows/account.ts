import { $, driver } from "@wdio/globals";

import { AutomationIds } from "../support/automationIds.js";
import { readCurrentAccount, writeCurrentAccount } from "../support/account-state.js";
import { setSensitiveScreen } from "../support/artifacts.js";
import {
  byId,
  inputTextOf,
  isAndroid,
  scrollIntoView,
  semanticValueOf,
  settleNavigation,
  tap,
  tapAt,
  textInputSelector
} from "../support/platform.js";
import { activateApp, terminateApp } from "./app.js";
import { acceptNotificationAlert } from "./alerts.js";
import { waitForPowerButton } from "./home.js";
import { dismissRatePromptIfPresent } from "./modals.js";
import { dismissIntroOverlayIfPresent } from "./onboarding.js";

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

const homeSettingsSelector = () => byId(AutomationIds.homeSettings);
const settingsScreenSelector = () => byId(AutomationIds.screenSettings);
const supportRowSelector = () => byId(AutomationIds.settingsSupport);

// The support-chat composer comes from the third-party `flutter_chat_ui`
// package and carries no automation ids, so we locate it structurally: the
// chat screen has exactly one text input.
const chatInputSelector = () => textInputSelector();

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

/** Navigate Home -> Settings -> Support chat and wait for the composer input. */
export async function openSupportChat(timeout = 15000): Promise<void> {
  await openSettingsScreen(timeout);
  // Support sits below the fold on a phone-sized Android screen.
  if (isAndroid()) {
    await (await $(byId(AutomationIds.screenTitle))).waitForExist({ timeout });
  }
  const row = await scrollIntoView(supportRowSelector());
  await row.waitForExist({ timeout });
  await tap(row);
  await (await $(chatInputSelector())).waitForExist({ timeout });
}

async function tapChatSend(): Promise<void> {
  // The composer's send IconButton (Icons.send) has no label, so tap the
  // far-right of the composer row, where it sits next to the input. Do not
  // match "Send" by label: on iOS 27 that is the keyboard's return key.
  const input = await $(chatInputSelector());
  const location = await input.getLocation();
  const size = await input.getSize();
  const rect = await driver.getWindowRect();
  // iOS reports points; Android reports pixels, so use a share of the width.
  const inset = isAndroid() ? Math.round(rect.width * 0.08) : 28;
  await tapAt(Math.round(rect.width - inset), Math.round(location.y + size.height / 2));
}

async function chatInputValue(): Promise<string> {
  try {
    const input = await $(chatInputSelector());
    if (!(await input.isExisting())) return "";
    return await inputTextOf(input);
  } catch {
    return "";
  }
}

/**
 * Tap send until the composer gives up the typed text. On iOS 27 the app takes
 * in text typed through XCTest a moment late, and a send tapped before that
 * does nothing while the field keeps showing the text.
 */
async function submitChatText(text: string, timeout = 15000): Promise<boolean> {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    await tapChatSend();
    const sent = await driver
      .waitUntil(async () => (await chatInputValue()) !== text, {
        timeout: 2000,
        interval: 250
      })
      .then(() => true)
      .catch(() => false);
    if (sent) return true;
  }
  return false;
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

  const input = await $(chatInputSelector());
  await input.waitForExist({ timeout: 10000 });
  await tap(input);
  try {
    await input.clearValue();
  } catch {
    // field may already be empty / not clearable — ignore
  }
  const text = `cc ${command}`;
  await input.setValue(text);
  if (!(await submitChatText(text))) {
    // Name only the command: its argument may be an account id.
    throw new Error(
      `Support chat never sent "cc ${command.split(" ")[0]}": the text stayed in the composer.`
    );
  }

  // Brief settle for the user bubble to echo; callers that need command
  // completion (see restoreAccount) wait on a real signal.
  await driver.pause(1000);
}

/**
 * Switch the active account by id via `cc restore <id>`, then relaunch to a
 * clean Home. Relaunch is deterministic regardless of the restore branch
 * (active restore reroutes to Settings; inactive stays on the chat screen).
 */
export async function restoreAccount(accountId: string): Promise<void> {
  // The chat now shows the account id: keep it out of failure screenshots until
  // the relaunch below leaves the chat. Left set when the restore throws.
  setSensitiveScreen(true);
  await sendChatCommand(`restore ${accountId}`);

  // Wait for the restore to complete before relaunching, so a slow network
  // restore is not killed mid-persist. An active restore reroutes to the
  // Settings screen only after the account API call + persist, which is a
  // reliable, history-proof completion signal. An inactive restore stays on the
  // chat with no nav and no dependable UI signal (the "OK" reply bubble can be
  // a stale message from a prior run's persisted chat history), so fall back to
  // a fixed settle covering the network round trip.
  const rerouted = await driver
    .waitUntil(async () => await elementExists(settingsScreenSelector()), {
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
  setSensitiveScreen(false);
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
