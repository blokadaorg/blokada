#!/usr/bin/env node

import process from "node:process";

import { resolveTargetDevice } from "../shared/lib/devices.mjs";
import { getDeviceLogOutputDir, pullRecentDeviceLog } from "./lib/log.mjs";

async function main() {
  const device = await resolveTargetDevice({
    autoSelectFirst: true,
    interactive: false
  });

  const result = await pullRecentDeviceLog({
    bundleId: process.env.APP_BUNDLE_ID ?? "net.blocka.app",
    device,
    lines: process.env.LINES ?? "200",
    outputDir: getDeviceLogOutputDir(),
    save: true,
    window: process.env.WINDOW ?? "1h"
  });

  if (result.text) {
    process.stdout.write(result.text);
    if (!result.text.endsWith("\n")) {
      process.stdout.write("\n");
    }
  }

  process.stderr.write(
    `Saved filtered log to ${result.artifactPath ?? "(not saved)"} and full copy to ${result.fullArtifactPath}\n`
  );
}

await main();
