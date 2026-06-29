import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

import type { Options } from "@wdio/types";

import { buildCapabilities } from "./scripts/lib/capabilities.mjs";
import { getAppiumServerConfig } from "./scripts/lib/paths.mjs";

const logLevel =
  (process.env.WDIO_LOG_LEVEL as Options.WebDriverLogTypes | undefined) ?? "info";
const server = getAppiumServerConfig(process.env);

// Ordered by account-state lifecycle: inactive-account scenarios first,
// active-account scenarios last, so the suite ends in the active state (the
// default most scenarios / manual inspection expect) and mirrors the real user
// journey (inactive -> paywall -> activate). Each spec self-provisions its
// account state, so correctness is order-independent; this list just pins the
// resting state. New specs: insert in account-state order.
const allSpecs = [
  "./src/specs/smoke/paywall.spec.ts", // inactive account
  "./src/specs/smoke/dns-onboarding.spec.ts", // active account; installs DNS profile, leaves protection ON
  "./src/specs/smoke/tab-navigation.spec.ts", // active account; home-hub navigation (no state change)
  "./src/specs/smoke/settings-navigation.spec.ts", // active account; settings sub-pages (no state change)
  "./src/specs/smoke/power-pause.spec.ts" // active account; turns off then re-activates -> resting state
];
// CI runs one step per scenario (so each shows separately) by setting WDIO_SPEC
// to a single spec path; when unset, the whole suite runs in order.
const specFilter = process.env.WDIO_SPEC?.trim();

// One JUnit file per scenario, consumed by scripts/junit-summary.mjs for the CI
// run summary and uploaded as an artifact. The filename is namespaced by spec so
// separate per-scenario wdio processes (each worker cid is 0-0) don't collide.
const junitDir = resolve(process.cwd(), "..", "output", "junit");
const junitSpecBase =
  specFilter?.split("/").pop()?.replace(/\.spec\.ts$/, "") ?? "all";

const rawConfig = {
  runner: "local",
  specs: specFilter ? [specFilter] : allSpecs,
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
        outputFileFormat: (options: { cid: string }) =>
          `results-${junitSpecBase}-${options.cid}.xml`
      }
    ]
  ],
  services: [],
  capabilities: [buildCapabilities(process.env)],
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
