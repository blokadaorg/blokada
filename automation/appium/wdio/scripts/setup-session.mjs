#!/usr/bin/env node

import { ensureAppiumRuntime } from "./lib/appium-runtime.mjs";
import { resolveTargetDevice, shellQuote } from "./lib/devices.mjs";
import { getProjectPaths } from "./lib/paths.mjs";

const outputJson = process.argv.includes("--json");

async function main() {
  const paths = getProjectPaths();
  await ensureAppiumRuntime({ log: console.error });
  const device = await resolveTargetDevice();

  const payload = {
    appiumHome: paths.appiumHome,
    iosUdid: device.udid,
    iosDeviceName: device.name
  };

  if (outputJson) {
    process.stdout.write(`${JSON.stringify(payload)}\n`);
    return;
  }

  process.stdout.write(
    [
      `export APPIUM_HOME=${shellQuote(payload.appiumHome)}`,
      `export IOS_UDID=${shellQuote(payload.iosUdid)}`,
      `export IOS_DEVICE_NAME=${shellQuote(payload.iosDeviceName)}`
    ].join("\n")
  );
}

await main();
