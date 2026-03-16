#!/usr/bin/env node

import { ensureAppiumRuntime } from "./lib/appium-runtime.mjs";

try {
  await ensureAppiumRuntime({ installDriver: false });
} catch (error) {
  console.error(error.message || error);
  process.exit(1);
}
