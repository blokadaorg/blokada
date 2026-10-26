#!/usr/bin/env node

// Android smoke runner: makes sure an Appium server with the UiAutomator2
// driver is listening (reusing one that already is), then runs WebdriverIO
// with wdio.android.conf.ts. The APK must already be installed on ANDROID_UDID.

import process from "node:process";
import { createWriteStream } from "node:fs";
import { mkdir } from "node:fs/promises";
import { spawn, spawnSync } from "node:child_process";

import { isAppiumServerReady, waitForAppiumServer } from "./lib/appium-runtime.mjs";
import { getAppiumServerConfig, getProjectPaths } from "./lib/paths.mjs";

const UIAUTOMATOR2_DRIVER_VERSION = "8.7.0";

function appiumEnv(env) {
  return { ...env, APPIUM_HOME: getProjectPaths(env).appiumHome };
}

function ensureUiAutomator2Driver(env) {
  const { appiumBinary } = getProjectPaths(env);
  const list = spawnSync(appiumBinary, ["driver", "list", "--installed", "--json"], {
    encoding: "utf8",
    env: appiumEnv(env)
  });
  if (list.status !== 0) {
    throw new Error(list.stderr || "appium driver list failed");
  }
  const installed = JSON.parse(list.stdout || "{}").uiautomator2?.version;
  if (installed === UIAUTOMATOR2_DRIVER_VERSION) {
    return;
  }
  if (installed) {
    spawnSync(appiumBinary, ["driver", "uninstall", "uiautomator2"], {
      stdio: "inherit",
      env: appiumEnv(env)
    });
  }
  console.error(`Installing Appium uiautomator2@${UIAUTOMATOR2_DRIVER_VERSION}...`);
  const install = spawnSync(
    appiumBinary,
    ["driver", "install", `uiautomator2@${UIAUTOMATOR2_DRIVER_VERSION}`],
    { stdio: "inherit", env: appiumEnv(env) }
  );
  if (install.status !== 0) {
    throw new Error("Failed to install the Appium uiautomator2 driver.");
  }
}

async function startAppium(env) {
  if (await isAppiumServerReady(env)) {
    console.error("Reusing the Appium server that is already listening.");
    return async () => {};
  }
  ensureUiAutomator2Driver(env);
  const paths = getProjectPaths(env);
  const { host, port, path } = getAppiumServerConfig(env);
  await mkdir(paths.outputDir, { recursive: true });
  // Not uploaded by CI: responses include the clipboard read during activation.
  const logFile = `${paths.outputDir}/appium-android-server.log`;
  const output = createWriteStream(logFile, { flags: "w" });
  const child = spawn(
    paths.appiumBinary,
    ["--address", host, "--port", String(port), "--base-path", path, "--use-drivers", "uiautomator2"],
    { env: appiumEnv(env), stdio: ["ignore", "pipe", "pipe"] }
  );
  child.stdout.pipe(output);
  child.stderr.pipe(output);
  try {
    await waitForAppiumServer(env, 60000);
  } catch (error) {
    child.kill("SIGTERM");
    throw error;
  }
  console.error(`Started Appium on ${host}:${port}; logs: ${logFile}`);
  return async () => {
    if (child.exitCode == null) {
      child.kill("SIGTERM");
      await new Promise((resolve) => child.once("exit", resolve));
    }
    output.end();
  };
}

async function main() {
  const stopAppium = await startAppium(process.env);
  const child = spawn(
    process.execPath,
    ["./node_modules/.bin/wdio", "run", "wdio.android.conf.ts"],
    { stdio: "inherit", env: process.env }
  );
  process.on("SIGINT", () => child.kill("SIGINT"));
  process.on("SIGTERM", () => child.kill("SIGTERM"));
  const exitCode = await new Promise((resolve) => {
    child.once("error", () => resolve(1));
    child.once("exit", (code, signal) => resolve(signal ? 1 : (code ?? 1)));
  });
  await stopAppium();
  process.exit(Number(exitCode));
}

await main();
