#!/usr/bin/env node

import { ensureAppiumRuntime } from "./lib/appium-runtime.mjs";
import {
  isSimulatorMode,
  resolveAppDisplayName,
  resolveAppFlavor,
  resolveInstallTarget,
  resolvePrimaryBundleId
} from "./lib/app-targets.mjs";
import { resolveTargetDevice, shellQuote } from "../../../shared/lib/devices.mjs";
import { getProjectPaths } from "./lib/paths.mjs";
import { resolveSimulatorDevice } from "./lib/sim.mjs";

const outputJson = process.argv.includes("--json");

async function main() {
  const paths = getProjectPaths();
  await ensureAppiumRuntime({ log: console.error });
  const device = isSimulatorMode(process.env)
    ? resolveSimulatorDevice()
    : await resolveTargetDevice();

  const payload = {
    appiumHome: paths.appiumHome,
    appDisplayName: resolveAppDisplayName(process.env),
    appBundleId: resolvePrimaryBundleId(process.env),
    appFlavor: resolveAppFlavor(process.env),
    appInstallTarget: resolveInstallTarget(process.env),
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
      `export APP_BUNDLE_ID=${shellQuote(payload.appBundleId)}`,
      `export APP_DISPLAY_NAME=${shellQuote(payload.appDisplayName)}`,
      `export APP_FLAVOR=${shellQuote(payload.appFlavor)}`,
      `export APPIUM_APP_INSTALL_TARGET=${shellQuote(payload.appInstallTarget)}`,
      `export IOS_UDID=${shellQuote(payload.iosUdid)}`,
      `export IOS_DEVICE_NAME=${shellQuote(payload.iosDeviceName)}`
    ].join("\n")
  );
}

await main();
