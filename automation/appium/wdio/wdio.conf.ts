import type { Options } from "@wdio/types";

import { buildCapabilities } from "./scripts/lib/capabilities.mjs";
import { getAppiumServerConfig } from "./scripts/lib/paths.mjs";

const logLevel =
  (process.env.WDIO_LOG_LEVEL as Options.WebDriverLogTypes | undefined) ?? "info";
const server = getAppiumServerConfig(process.env);

const rawConfig = {
  runner: "local",
  specs: ["./src/specs/smoke/**/*.ts"],
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
  reporters: ["spec"],
  services: [],
  capabilities: [buildCapabilities(process.env)],
  // Sleep the device screen when the run finishes so the CI iPhone is not
  // left awake at full brightness between runs. Pairs with the wake step in
  // `make appium-test` (relaunch before the run). Best-effort — a lock
  // failure must never fail the suite.
  after: async function () {
    // Log on both paths so every run's log proves this hook executed.
    console.warn("Post-run: locking device screen");
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
