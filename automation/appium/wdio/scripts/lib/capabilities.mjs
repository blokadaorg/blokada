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
    // First-match `$`, as in wdio.conf.ts (WebdriverIO 10 defaults to strict).
    strictSelectors: false,
    logLevel: (env.WDIO_LOG_LEVEL ?? "warn").toLowerCase()
  };
}

export const ANDROID_SIX_PACKAGE = "org.blokada.sex";
export const ANDROID_LAUNCH_ACTIVITY = "ui.MainActivity";

// Android emulator/device via UiAutomator2. The APK is installed beforehand by
// `make appium-test-android` (or CI), so the session only attaches to it.
export function buildAndroidCapabilities(env = process.env) {
  if (!env.ANDROID_UDID) {
    throw new Error("ANDROID_UDID is not set; it names the adb device under test.");
  }
  return {
    platformName: "Android",
    "appium:automationName": "UiAutomator2",
    "appium:udid": env.ANDROID_UDID,
    "appium:appPackage": env.APP_BUNDLE_ID ?? ANDROID_SIX_PACKAGE,
    "appium:appActivity": env.ANDROID_APP_ACTIVITY ?? ANDROID_LAUNCH_ACTIVITY,
    "appium:noReset": true,
    "appium:newCommandTimeout": 240,
    // Flutter redraws continuously, so UiAutomator's wait-for-idle before each
    // lookup times out every time (~10s per command). Same fix as the iOS
    // waitForIdleTimeout above.
    // A driver setting on UiAutomator2, not a capability like on XCUITest.
    "appium:settings[waitForIdleTimeout]": 0,
    // Hosted emulators are slow to install the UiAutomator2 server on first use.
    "appium:uiautomator2ServerInstallTimeout": 120000,
    "appium:adbExecTimeout": 60000,
    // Phones that block adb from writing global settings (OnePlus, Xiaomi)
    // otherwise fail session start on the hidden API policy reset.
    "appium:ignoreHiddenApiPolicyError": true
  };
}
