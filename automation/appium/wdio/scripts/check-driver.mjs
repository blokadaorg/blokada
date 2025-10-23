#!/usr/bin/env node

import { execSync } from "node:child_process";

try {
  const output = execSync("appium driver list --installed --json", {
    encoding: "utf8"
  });
  const data = JSON.parse(output);
  if (!data.xcuitest || data.xcuitest.installed !== true) {
    const appiumHome = process.env.APPIUM_HOME;
    const hint = appiumHome ? ` (APPIUM_HOME=${appiumHome})` : "";
    throw new Error(
      `Appium xcuitest driver missing${hint}. Run 'appium driver install xcuitest' once per machine.`
    );
  }
} catch (error) {
  if (error.name === "SyntaxError") {
    console.error("Unexpected output from Appium driver list. Run 'appium driver list --installed' manually.");
  } else if (error.stdout || error.stderr) {
    process.stderr.write(error.stdout ?? "");
    process.stderr.write(error.stderr ?? "");
    console.error(error.message || error);
  } else {
    console.error(error.message || error);
  }
  process.exit(1);
}
