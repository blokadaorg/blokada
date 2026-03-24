import { getAppiumServerConfig, getProjectPaths } from "./paths.mjs";
import { resolvePrimaryBundleId } from "./app-targets.mjs";

export function buildCapabilities(env = process.env) {
  const paths = getProjectPaths(env);

  return {
    platformName: "iOS",
    "appium:automationName": "XCUITest",
    "appium:bundleId": resolvePrimaryBundleId(env),
    "appium:xcodeOrgId": env.IOS_TEAM_ID ?? "HQH5AFGB68",
    "appium:xcodeSigningId": env.IOS_SIGNING_IDENTITY ?? "Apple Development",
    "appium:updatedWDABundleId":
      env.WDA_BUNDLE_ID ?? "net.blocka.app.WebDriverAgentRunner",
    "appium:xcodeConfigFile": paths.signingConfigPath,
    "appium:showXcodeLog": env.SHOW_XCODE_LOG === "0" ? false : true,
    "appium:udid": env.IOS_UDID,
    "appium:deviceName": env.IOS_DEVICE_NAME ?? "iPhone connected via USB",
    "appium:useNewWDA": false,
    "appium:noReset": true,
    "appium:newCommandTimeout": 240
  };
}

export function getRemoteOptions(env = process.env) {
  const server = getAppiumServerConfig(env);

  return {
    protocol: "http",
    hostname: server.host,
    port: server.port,
    path: server.path,
    capabilities: buildCapabilities(env),
    logLevel: (env.WDIO_LOG_LEVEL ?? "warn").toLowerCase()
  };
}
