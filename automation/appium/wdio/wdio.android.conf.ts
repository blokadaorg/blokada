import { execFileSync } from "node:child_process";

import type { Options } from "@wdio/types";
import { SevereServiceError } from "webdriverio";

import { buildAndroidCapabilities, ANDROID_SIX_PACKAGE } from "./scripts/lib/capabilities.mjs";
import { config as iosConfig } from "./wdio.conf.js";

// Android smoke run (UiAutomator2, emulator). Reuses the iOS config for the
// runner, reporters and hook-failure capture, and replaces the iOS-only parts:
// specs, capabilities, the devicectl wake and the screen lock.
//
// Scope is the specs that work on Android so far. android-protection replaces
// dns-onboarding (Private DNS instead of the iOS DNS profile) and must run
// first: the rest expect protection on.
// Shared specs default APP_BUNDLE_ID to the iOS bundle id; set the Android
// package before workers start so they launch the right app.
const packageName: string = process.env.APP_BUNDLE_ID ?? ANDROID_SIX_PACKAGE;
process.env.APP_BUNDLE_ID = packageName;

function adb(args: string[]): string {
  const serial = process.env.ANDROID_UDID;
  if (!serial) {
    throw new Error("ANDROID_UDID is not set; it names the adb device under test.");
  }
  return execFileSync("adb", ["-s", serial, ...args], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"]
  });
}

// The device's own Private DNS setting, put back after the run so a phone
// isn't left on the test account's hostname. Kept in memory, never logged.
const privateDnsKeys = ["private_dns_mode", "private_dns_specifier"] as const;
let savedPrivateDns: Map<string, string> | undefined;

// Restores each key on its own and keeps the ones that failed, so the exit
// handler can try them again.
function restorePrivateDns(): void {
  if (!savedPrivateDns) return;
  for (const [key, value] of [...savedPrivateDns]) {
    try {
      // `settings get` prints "null" for a key that was never set.
      adb(
        value === "null"
          ? ["shell", "settings", "delete", "global", key]
          : ["shell", "settings", "put", "global", key, value]
      );
      savedPrivateDns.delete(key);
    } catch {
      // The adb error carries the command line, which holds the hostname.
      console.error(`Could not restore ${key} on the device; check Private DNS in Settings.`);
      process.exitCode = 1;
    }
  }
  if (savedPrivateDns.size === 0) savedPrivateDns = undefined;
}

// WebdriverIO exits on SIGINT/SIGTERM without calling onComplete. The adb
// calls are synchronous, so they still run from the exit event; after a full
// restore in onComplete it is a no-op, and workers never saved anything.
process.once("exit", restorePrivateDns);

// The spec sets Private DNS with `settings put global`, grants the VPN with
// appops, and Appium reads the clipboard through its own keyboard. Some phones
// (OnePlus, Oppo, Xiaomi) block all three over adb until "Disable permission
// monitoring" (or "USB debugging (Security settings)") is turned on in
// Developer options. Fail up front with that hint instead of mid-run.
function prepareDevice(): void {
  try {
    adb(["shell", "appops", "set", packageName, "ACTIVATE_VPN", "allow"]);
    savedPrivateDns = new Map(
      privateDnsKeys.map((key) => [key, adb(["shell", "settings", "get", "global", key]).trim()])
    );
    adb(["shell", "settings", "put", "global", "private_dns_mode", "off"]);
  } catch (e) {
    // A plain Error in onPrepare is only logged and the specs run anyway.
    throw new SevereServiceError(
      "This device blocks adb from changing settings, so the VPN and Private DNS can't be set up. " +
        "Enable 'Disable permission monitoring' (OnePlus/Oppo) or 'USB debugging (Security settings)' " +
        `(Xiaomi) in Developer options, then run again. (${e instanceof Error ? e.message : String(e)})`
    );
  }
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
  // run-wdio-android.mjs may run some spec files a second time (see
  // scripts/lib/instrumentation-retry.mjs); the attempt number keeps both
  // attempts' JUnit files apart.
  reporters: (iosConfig.reporters ?? []).map((reporter) =>
    Array.isArray(reporter) && reporter[0] === "junit"
      ? [
          "junit",
          {
            ...(reporter[1] as object),
            outputFileFormat: (options: { cid: string }) =>
              `results-${process.env.WDIO_ATTEMPT ?? "1"}-${options.cid}.xml`
          }
        ]
      : reporter
  ),
  onPrepare: function (...args: unknown[]) {
    (iosConfig.onPrepare as (...a: unknown[]) => void)(...args);
    // Permissions a user grants by hand: notifications (prompted on first
    // activation) and the VPN consent (Plus accounts). Then turn Private DNS
    // off so android-protection always starts from the onboarding sheet.
    // The notification permission exists from Android 13 (API 33).
    if (Number(adb(["shell", "getprop", "ro.build.version.sdk"]).trim()) >= 33) {
      adb(["shell", "pm", "grant", packageName, "android.permission.POST_NOTIFICATIONS"]);
    }
    prepareDevice();
  },
  onComplete: function () {
    restorePrivateDns();
  },
  beforeSession: undefined,
  after: undefined
};

export const config = androidConfig as unknown as Options.Testrunner;

export default config;
