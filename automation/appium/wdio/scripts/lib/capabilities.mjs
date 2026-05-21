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
    "appium:newCommandTimeout": 240,
    // Blokada is a Flutter app: its surface renders/animates continuously,
    // so XCUITest's default "wait for the app to be idle (no animations)"
    // before every query/screenshot frequently never settles. When that
    // wait times out non-idle, WDA returns a black screenshot and an empty
    // element tree, so element lookups fail intermittently (e.g.
    // ~automation.power_toggle / Settings cells) even though the app is
    // perfectly visible on the device. 0 disables the idle wait — the
    // root cause of the appium-smoke flakiness.
    "appium:waitForIdleTimeout": 0
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
