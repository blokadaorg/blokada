import { getAppiumServerConfig, getProjectPaths } from "./paths.mjs";
import { isSimulatorMode, resolvePrimaryBundleId } from "./app-targets.mjs";

export function buildCapabilities(env = process.env) {
  const paths = getProjectPaths(env);
  const simMode = isSimulatorMode(env);

  const caps = {
    platformName: "iOS",
    "appium:automationName": "XCUITest",
    "appium:bundleId": resolvePrimaryBundleId(env),
    "appium:showXcodeLog": env.SHOW_XCODE_LOG === "0" ? false : true,
    "appium:udid": env.IOS_UDID,
    "appium:deviceName": env.IOS_DEVICE_NAME ?? "iPhone connected via USB",
    "appium:noReset": true,
    "appium:newCommandTimeout": 240
  };

  if (simMode) {
    // Simulator: WDA runs unsigned and Appium manages its own bundled build,
    // so we skip the signing-identity caps the physical-device path needs.
    caps["appium:useNewWDA"] = true;
  } else {
    // Physical device: WDA needs a signed bundle id and survives across runs.
    caps["appium:xcodeOrgId"] = env.IOS_TEAM_ID ?? "HQH5AFGB68";
    caps["appium:xcodeSigningId"] = env.IOS_SIGNING_IDENTITY ?? "Apple Development";
    caps["appium:updatedWDABundleId"] =
      env.WDA_BUNDLE_ID ?? "net.blocka.app.WebDriverAgentRunner";
    caps["appium:xcodeConfigFile"] = paths.signingConfigPath;
    caps["appium:useNewWDA"] = false;
  }

  return caps;
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
