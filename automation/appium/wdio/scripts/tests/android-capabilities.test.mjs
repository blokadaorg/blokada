import test from "node:test";
import assert from "node:assert/strict";

import { buildAndroidCapabilities } from "../lib/capabilities.mjs";

test("buildAndroidCapabilities targets the six package on the given device", () => {
  const caps = buildAndroidCapabilities({ ANDROID_UDID: "emulator-5554" });
  assert.equal(caps.platformName, "Android");
  assert.equal(caps["appium:automationName"], "UiAutomator2");
  assert.equal(caps["appium:udid"], "emulator-5554");
  assert.equal(caps["appium:appPackage"], "org.blokada.sex");
  assert.equal(caps["appium:appActivity"], "ui.MainActivity");
  assert.equal(caps["appium:noReset"], true);
  assert.equal(caps["appium:waitForIdleTimeout"], 0);
});

test("buildAndroidCapabilities honours APP_BUNDLE_ID", () => {
  const caps = buildAndroidCapabilities({
    ANDROID_UDID: "emulator-5556",
    APP_BUNDLE_ID: "org.example.app"
  });
  assert.equal(caps["appium:appPackage"], "org.example.app");
});

test("buildAndroidCapabilities requires ANDROID_UDID", () => {
  assert.throws(() => buildAndroidCapabilities({}), /ANDROID_UDID/);
});
