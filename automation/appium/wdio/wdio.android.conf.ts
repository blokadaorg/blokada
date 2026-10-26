import { execFileSync } from "node:child_process";

import type { Options } from "@wdio/types";

import { buildAndroidCapabilities, ANDROID_SIX_PACKAGE } from "./scripts/lib/capabilities.mjs";
import { config as iosConfig } from "./wdio.conf.js";

// Android smoke run (UiAutomator2, emulator). Reuses the iOS config for the
// runner, reporters and hook-failure capture, and replaces the iOS-only parts:
// specs, capabilities, the devicectl wake and the screen lock.
//
// Scope is the specs that work on Android so far. android-protection replaces
// dns-onboarding (Private DNS instead of the iOS DNS profile) and must run
// first: the rest expect protection on.
const packageName = process.env.APP_BUNDLE_ID ?? ANDROID_SIX_PACKAGE;

function adb(args: string[]): void {
  const serial = process.env.ANDROID_UDID;
  if (!serial) {
    throw new Error("ANDROID_UDID is not set; it names the adb device under test.");
  }
  execFileSync("adb", ["-s", serial, ...args], { stdio: "inherit" });
}

const androidConfig = {
  ...iosConfig,
  // Command logs at info would print the clipboard read by android-protection,
  // which holds the Private DNS hostname (it carries the device tag).
  logLevel: (process.env.WDIO_LOG_LEVEL as Options.WebDriverLogTypes | undefined) ?? "warn",
  specs: [
    "./src/specs/smoke/android-protection.spec.ts", // restores active; turns protection on via Private DNS
    "./src/specs/smoke/tab-navigation.spec.ts",
    "./src/specs/smoke/settings-navigation.spec.ts",
    "./src/specs/smoke/blocklist-toggle.spec.ts",
    "./src/specs/smoke/privacy-pulse-range.spec.ts",
    "./src/specs/smoke/power-pause.spec.ts" // turns off then re-activates -> resting state
  ],
  capabilities: [buildAndroidCapabilities(process.env)],
  onPrepare: function (...args: unknown[]) {
    (iosConfig.onPrepare as (...a: unknown[]) => void)(...args);
    // Permissions a user grants by hand: notifications (prompted on first
    // activation) and the VPN consent (Plus accounts). Then turn Private DNS
    // off so android-protection always starts from the onboarding sheet.
    adb(["shell", "pm", "grant", packageName, "android.permission.POST_NOTIFICATIONS"]);
    adb(["shell", "appops", "set", packageName, "ACTIVATE_VPN", "allow"]);
    adb(["shell", "settings", "put", "global", "private_dns_mode", "off"]);
  },
  beforeSession: undefined,
  after: undefined
};

export const config = androidConfig as unknown as Options.Testrunner;

export default config;
