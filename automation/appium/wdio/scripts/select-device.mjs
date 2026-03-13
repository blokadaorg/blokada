#!/usr/bin/env node

import { resolveTargetDevice } from "./lib/devices.mjs";

async function main() {
  try {
    const device = await resolveTargetDevice();
    console.error(
      `Selected device ${device.name} (iOS ${device.os}) – ${device.udid}`
    );
    process.stdout.write(device.udid);
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}

await main();
