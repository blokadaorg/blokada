import { existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import { activateApp } from "../flows/app.js";

// Pre-flight for every iOS spec: make sure the phone's screen is on, past the
// lock screen, and showing the app before any spec code runs.
//
// The suite's "wake" (`devicectl process launch` in the Makefile and
// beforeSession) only launches the app; it neither lights a dark screen nor
// dismisses the lock screen (cover sheet). With Auto-Lock enabled the app then
// runs behind the cover sheet ("running-active-NotVisible"), screenshots come
// back black, and every spec burns minutes waiting for elements that can never
// appear. Registered as a mocha root `beforeAll` (mochaOpts.require), so a
// failure here fails the spec immediately, unlike a wdio `before` hook whose
// errors are only logged.
//
// Once one spec's pre-flight fails, later specs fail straight away via a marker
// file (cleared per run by clearPreflightFailure in onPrepare), so a dead phone
// costs about a minute instead of the whole suite.

const markerPath = resolve(process.cwd(), "..", "output", ".preflight-failed");
const bundleId = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

export function clearPreflightFailure(): void {
  rmSync(markerPath, { force: true });
}

async function foregroundBundleId(): Promise<string | undefined> {
  try {
    const info = (await driver.execute("mobile: activeAppInfo")) as { bundleId?: string };
    return info?.bundleId;
  } catch (error) {
    console.warn(`Pre-flight: activeAppInfo failed: ${String(error)}`);
    return undefined;
  }
}

async function swipeUpFromBottom(): Promise<void> {
  const { width, height } = await driver.getWindowSize();
  const x = Math.round(width / 2);
  await driver.performActions([
    {
      type: "pointer",
      id: "finger1",
      parameters: { pointerType: "touch" },
      actions: [
        { type: "pointerMove", duration: 0, x, y: height - 5 },
        { type: "pointerDown", button: 0 },
        { type: "pointerMove", duration: 250, x, y: Math.round(height * 0.3) },
        { type: "pointerUp", button: 0 }
      ]
    }
  ]);
  await driver.releaseActions();
}

// Each step is best-effort; the foreground check after it decides success.
const recoverySteps: Array<{ name: string; run: () => Promise<void> }> = [
  { name: "activate app", run: async () => {} },
  {
    name: "unlock",
    run: async () => {
      await driver.execute("mobile: unlock");
    }
  },
  {
    // Lights a dark screen and lands on the cover sheet; the swipe dismisses
    // it (the CI phone has no passcode).
    name: "home press + swipe up",
    run: async () => {
      await driver.execute("mobile: pressButton", { name: "home" });
      await driver.pause(800);
      await swipeUpFromBottom();
    }
  },
  {
    // If the home press did not wake the display, a power press does.
    name: "power press + swipe up",
    run: async () => {
      await driver.execute("mobile: performIoHidEvent", {
        page: 0x0c,
        usage: 0x30,
        durationSeconds: 0.1
      });
      await driver.pause(800);
      await swipeUpFromBottom();
    }
  }
];

async function ensureAppVisible(): Promise<void> {
  let seen: string | undefined;
  for (const step of recoverySteps) {
    try {
      await step.run();
      await driver.pause(800);
      await activateApp(bundleId);
      await driver.pause(1500);
    } catch (error) {
      console.warn(`Pre-flight: "${step.name}" failed: ${String(error)}`);
    }
    seen = await foregroundBundleId();
    if (seen === bundleId) {
      console.warn(`Pre-flight: ${bundleId} is in the foreground (after "${step.name}")`);
      return;
    }
    console.warn(`Pre-flight: after "${step.name}" the foreground app is ${seen ?? "unknown"}`);
  }
  throw new Error(
    `Pre-flight: ${bundleId} is not visible on the phone (foreground app: ${seen ?? "unknown"}). ` +
      "The screen is likely off or on the lock screen. Check that Auto-Lock is set to Never " +
      "on the CI iPhone."
  );
}

export const mochaHooks = {
  async beforeAll(this: unknown): Promise<void> {
    if (!driver.isIOS) return;
    if (existsSync(markerPath)) {
      throw new Error(
        "Pre-flight: skipped because an earlier spec found the app not visible on the phone; see the first failure."
      );
    }
    try {
      await ensureAppVisible();
    } catch (error) {
      mkdirSync(dirname(markerPath), { recursive: true });
      writeFileSync(markerPath, String(error));
      throw error;
    }
  }
};
