#!/usr/bin/env node

import process from "node:process";

import { resolveTargetDevice } from "../shared/lib/devices.mjs";
import {
  getDeviceCrashOutputDir,
  getDeviceLogOutputDir,
  pullRecentCrashReport,
  pullRecentDeviceLog
} from "./lib/log.mjs";

async function main() {
  const device = await resolveTargetDevice({
    autoSelectFirst: true,
    interactive: false
  });
  const artifact = String(process.env.ARTIFACT ?? "log")
    .trim()
    .toLowerCase();
  const bundleId = process.env.APP_BUNDLE_ID ?? "net.blocka.app";

  if (artifact === "crash") {
    const result = await pullRecentCrashReport({
      bundleId,
      device,
      outputDir: getDeviceCrashOutputDir(),
      save: true
    });

    if (result.text) {
      process.stdout.write(result.text);
      if (!result.text.endsWith("\n")) {
        process.stdout.write("\n");
      }
    }

    process.stderr.write(`Saved crash report to ${result.artifactPath ?? "(not saved)"}\n`);
    return;
  }

  if (artifact !== "log") {
    throw new Error(`Unsupported ARTIFACT='${artifact}'. Expected 'log' or 'crash'.`);
  }

  const result = await pullRecentDeviceLog({
    bundleId,
    device,
    lines: process.env.LINES ?? "400",
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
