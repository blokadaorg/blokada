import { execFileSync } from "node:child_process";

import { $, driver } from "@wdio/globals";

import { AutomationIds } from "../support/automationIds.js";
import { byId, tap } from "../support/platform.js";
import { activateApp, terminateApp } from "./app.js";
import { getProtectionState, waitForProtectionActive } from "./home.js";

// Android activation for a Cloud account goes through system Private DNS: the
// app's sheet shows a per-device hostname with a Copy button and opens
// Settings, where a user would paste it. The harness reads the clipboard and applies it
// with `adb shell settings` instead of driving the vendor-specific Settings UI.
//
// The hostname contains the device tag. Never print or log it, and keep it out
// of error messages (execFileSync errors embed the full command line).

const sheetSelector = () => byId(AutomationIds.dnsOnboardingSheet);
const openSettingsSelector = () => byId(AutomationIds.dnsOpenSettings);
const copyHostnameSelector = () => byId(AutomationIds.dnsCopyHostname);

function adbSerial(): string {
  const serial = (process.env.ANDROID_UDID ?? "").trim();
  if (!serial) {
    throw new Error("ANDROID_UDID is not set; it names the adb device under test.");
  }
  return serial;
}

/** Run `adb -s <serial> shell <args>` without ever echoing the arguments. */
function adbShell(args: string[], what: string): void {
  try {
    execFileSync("adb", ["-s", adbSerial(), "shell", ...args], { stdio: "ignore" });
  } catch (error) {
    const status = (error as { status?: number }).status;
    throw new Error(`adb shell failed while ${what} (exit ${String(status)}).`);
  }
}

export async function waitForPrivateDnsSheet(timeout = 10000): Promise<boolean> {
  return (await $(sheetSelector()))
    .waitForExist({ timeout })
    .then(() => true)
    .catch(() => false);
}

/** Tap "Open Settings" until the app hands over to system Settings. */
async function openSystemSettingsFromSheet(appPackage: string): Promise<void> {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    if ((await driver.getCurrentPackage()) !== appPackage) {
      return;
    }
    await tap(await $(openSettingsSelector()));
    await driver.pause(2000);
  }
  if ((await driver.getCurrentPackage()) === appPackage) {
    throw new Error("Private DNS sheet's Open Settings did not leave the app.");
  }
}

async function readCopiedHostname(): Promise<string> {
  const encoded = await driver.getClipboard();
  const hostname = Buffer.from(String(encoded), "base64").toString("utf8").trim();
  if (!/^[a-z0-9-]+(\.[a-z0-9-]+)+$/i.test(hostname)) {
    throw new Error(
      `Clipboard does not hold a Private DNS hostname (length ${hostname.length}).`
    );
  }
  return hostname;
}

/**
 * From the Private DNS onboarding sheet: copy the hostname via the app, apply
 * it as the system Private DNS, return to the app and wait for protection to
 * turn on. Returns how the app noticed the change ("resume" or "cold restart").
 */
export async function enablePrivateDnsFromSheet(appPackage: string): Promise<string> {
  await tap(await $(copyHostnameSelector()));
  const hostname = await readCopiedHostname();
  await openSystemSettingsFromSheet(appPackage);
  adbShell(
    ["settings", "put", "global", "private_dns_specifier", hostname],
    "setting the Private DNS hostname"
  );
  adbShell(
    ["settings", "put", "global", "private_dns_mode", "hostname"],
    "switching Private DNS to hostname mode"
  );

  // Coming back from Settings should be enough; if the app does not pick the
  // change up on resume, a cold start does.
  await activateApp(appPackage);
  const onResume = await waitForProtectionActive(20000)
    .then(() => true)
    .catch(() => false);
  if (onResume) {
    return "resume";
  }
  console.warn(
    `Protection still '${String(await getProtectionState())}' after returning from ` +
      "Settings; cold-restarting the app."
  );
  await terminateApp(appPackage);
  await activateApp(appPackage);
  await waitForProtectionActive(30000);
  return "cold restart";
}
