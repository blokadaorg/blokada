import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

import type { Options } from "@wdio/types";

import { buildCapabilities } from "./scripts/lib/capabilities.mjs";
import { getAppiumServerConfig } from "./scripts/lib/paths.mjs";
import { resetAccountState } from "./src/support/account-state.js";

const logLevel =
  (process.env.WDIO_LOG_LEVEL as Options.WebDriverLogTypes | undefined) ?? "info";
const server = getAppiumServerConfig(process.env);

// JUnit output dir (one file per spec, distinct by worker cid) consumed by
// scripts/junit-summary.mjs for the CI run summary and uploaded as an artifact.
const junitDir = resolve(process.cwd(), "..", "output", "junit");

const rawConfig = {
  runner: "local",
  // GROUPED BY ACCOUNT STATE: all inactive-account scenarios first, then all
  // active-account scenarios. Each spec's `before` calls ensureAccount{Inactive,
  // Active}, which restores the account only when the device isn't already on it
  // this run (tracked in output/.account-state, reset per run by onPrepare). So
  // grouping means the account is restored just ONCE per group — at the boundary,
  // not per spec — which is the bulk of the suite's time (each restore is an app
  // relaunch + support-chat command + network round trip). The suite ends active
  // (power-pause last), mirroring the real user journey (inactive -> paywall ->
  // activate).
  //
  // ADD A NEW SPEC INTO ITS ACCOUNT GROUP: inactive specs above the boundary,
  // active specs below it. Interleaving still passes (each ensureAccount* fixes
  // its own state) but forces an extra restore at every switch.
  specs: [
    // --- inactive account ---
    "./src/specs/smoke/paywall.spec.ts", // restores inactive (first spec of the run)
    "./src/specs/smoke/freemium-gate.spec.ts", // Advanced upgrade gate (restore skipped)
    // --- active account (boundary: dns-onboarding pays the one active restore) ---
    "./src/specs/smoke/dns-onboarding.spec.ts", // restores active; installs DNS profile, leaves protection ON
    "./src/specs/smoke/cold-restart-persistence.spec.ts", // protection survives kill+relaunch (restore skipped)
    "./src/specs/smoke/tab-navigation.spec.ts", // home-hub navigation (restore skipped)
    "./src/specs/smoke/settings-navigation.spec.ts", // settings sub-pages (restore skipped)
    "./src/specs/smoke/exceptions-crud.spec.ts", // add/verify/delete a custom exception (restore skipped)
    "./src/specs/smoke/account-status.spec.ts", // account header shows active subscription (restore skipped)
    "./src/specs/smoke/blocklist-toggle.spec.ts", // toggle a filter option + restore (restore skipped)
    "./src/specs/smoke/privacy-pulse-range.spec.ts", // 24h<->7d toplist range toggle (restore skipped)
    "./src/specs/smoke/activity.spec.ts", // Privacy Pulse -> Show All -> Activity screen (restore skipped)
    "./src/specs/smoke/power-pause.spec.ts" // turns off then re-activates -> resting state (restore skipped)
  ],
  maxInstances: 1,
  hostname: server.host,
  port: server.port,
  path: server.path,
  logLevel,
  framework: "mocha",
  mochaOpts: {
    timeout: 600000
  },
  autoCompileOpts: {
    autoCompile: true,
    tsNodeOpts: {
      project: `${process.cwd()}/tsconfig.json`,
      transpileOnly: true
    }
  },
  reporters: [
    "spec",
    [
      "junit",
      {
        outputDir: junitDir,
        outputFileFormat: (options: { cid: string }) => `results-${options.cid}.xml`
      }
    ]
  ],
  services: [],
  capabilities: [buildCapabilities(process.env)],
  // Reset the per-run account tracker once, before any worker starts, so the
  // first spec always restores (we can't trust the device's leftover state) and
  // later same-account specs can skip the restore. See account-state.ts.
  onPrepare: function () {
    resetAccountState();
  },
  // Wake the device before every worker session. `make appium-test` wakes the
  // device once before the whole run, but the `after` hook below sleeps it after
  // each spec file (each spec runs as its own sequential worker). Without this,
  // the second spec's WebDriverAgent session can't launch the app on the locked
  // screen ("...could not be, unlocked ... reason: Locked"). Re-waking here
  // mirrors the Makefile's wake and keeps the suite robust to any spec count.
  // Best-effort — never throw (WDA will still try to activate the app).
  beforeSession: function () {
    const udid = process.env.IOS_UDID;
    if (!udid) return;
    const bundleId = process.env.APP_BUNDLE_ID ?? "net.blocka.app";
    try {
      execFileSync(
        "xcrun",
        [
          "devicectl",
          "device",
          "process",
          "launch",
          "--terminate-existing",
          "--device",
          udid,
          bundleId
        ],
        { stdio: "ignore" }
      );
      console.warn("Pre-session: device woken");
    } catch (error) {
      console.warn(
        `Pre-session device wake failed (continuing; WDA will activate): ${String(error)}`
      );
    }
  },
  // Sleep the device screen when each spec finishes so the CI iPhone is not
  // left awake at full brightness between runs; `beforeSession` re-wakes it for
  // the next spec, and the final spec leaves it asleep. Best-effort — a lock
  // failure (or no active session) must never fail the suite.
  after: async function () {
    console.warn("Post-run: locking device screen");
    if (typeof browser === "undefined" || typeof browser.lock !== "function") {
      console.warn("Post-run: no active session; skipping device lock");
      return;
    }
    try {
      await browser.lock();
      console.warn("Post-run: device screen locked");
    } catch (error) {
      console.warn(`Post-run device lock failed: ${String(error)}`);
    }
  }
} as const;

export const config = rawConfig as unknown as Options.Testrunner;

export default config;
