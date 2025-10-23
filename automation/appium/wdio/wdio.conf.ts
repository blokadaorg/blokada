import { join } from "node:path";
import type { Options } from "@wdio/types";

const projectRoot = join(process.cwd(), "..", "..", "..");
const appiumConfigPath = join(projectRoot, ".appiumrc.yaml");
const signingConfigPath = process.env.IOS_XCODE_CONFIG_FILE ?? join(
  projectRoot,
  "ios",
  "App",
  "Config",
  "AppiumSigning.xcconfig"
);

const iosUdid = process.env.IOS_UDID;
const logLevel =
  (process.env.WDIO_LOG_LEVEL as Options.WebDriverLogTypes | undefined) ?? "info";
if (!iosUdid) {
  // eslint-disable-next-line no-console
  console.warn(
    "IOS_UDID is not set. WebDriverIO will attempt to use the first available device."
  );
}

const includeDebugSpecs =
  (process.env.WDIO_INCLUDE_DEBUG ?? "").trim() === "1";

const rawConfig = {
  runner: "local",
  specs: includeDebugSpecs
    ? ["./src/specs/**/*.ts"]
    : ["./src/specs/smoke/**/*.ts"],
  exclude: includeDebugSpecs ? [] : ["./src/specs/debug/**/*.ts"],
  maxInstances: 1,
  logLevel,
  framework: "mocha",
  mochaOpts: {
    timeout: 600000
  },
  autoCompileOpts: {
    autoCompile: true,
    tsNodeOpts: {
      project: join(process.cwd(), "tsconfig.json"),
      transpileOnly: true
    }
  },
  reporters: ["spec"],
  services: [
    [
      "appium",
      {
        command: "appium",
        args: {
          config: appiumConfigPath
        }
      }
    ]
  ],
  capabilities: [
    {
      platformName: "iOS",
      "appium:automationName": "XCUITest",
      "appium:bundleId": process.env.APP_BUNDLE_ID ?? "net.blocka.app",
      "appium:xcodeOrgId": process.env.IOS_TEAM_ID ?? "HQH5AFGB68",
      "appium:xcodeSigningId":
        process.env.IOS_SIGNING_IDENTITY ?? "Apple Development",
      "appium:updatedWDABundleId":
        process.env.WDA_BUNDLE_ID ?? "net.blocka.app.WebDriverAgentRunner",
      "appium:xcodeConfigFile": signingConfigPath,
      "appium:showXcodeLog":
        process.env.SHOW_XCODE_LOG === "0" ? false : true,
      "appium:udid": iosUdid,
      "appium:deviceName":
        process.env.IOS_DEVICE_NAME ?? "iPhone connected via USB",
      "appium:noReset": true,
      "appium:newCommandTimeout": 240
    }
  ]
} as const;

export const config = rawConfig as unknown as Options.Testrunner;

export default config;
