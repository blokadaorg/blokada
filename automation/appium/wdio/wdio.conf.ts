import type { Options } from "@wdio/types";

import {
  buildCapabilities
} from "./scripts/lib/capabilities.mjs";
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
  capabilities: [buildCapabilities(process.env)]
} as const;

export const config = rawConfig as unknown as Options.Testrunner;

export default config;
