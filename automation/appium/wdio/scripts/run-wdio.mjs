#!/usr/bin/env node

import process from "node:process";
import { spawn } from "node:child_process";

import {
  ensureLocalAppiumServer,
  terminateWebDriverAgent
} from "./lib/appium-runtime.mjs";

async function main() {
  const server = await ensureLocalAppiumServer({ log: console.error });

  const cleanup = async () => {
    await terminateWebDriverAgent({
      deviceIdentifier: process.env.IOS_UDID,
      log: console.error
    }).catch(() => undefined);
    await server.stop().catch(() => undefined);
  };

  const forwardSignal = (signal) => {
    child.kill(signal);
  };

  const child = spawn(
    process.execPath,
    [
      "./node_modules/.bin/wdio",
      "run",
      "wdio.conf.ts"
    ],
    {
      stdio: "inherit",
      env: process.env
    }
  );

  process.on("SIGINT", () => forwardSignal("SIGINT"));
  process.on("SIGTERM", () => forwardSignal("SIGTERM"));

  try {
    const exitCode = await new Promise((resolve, reject) => {
      child.once("error", reject);
      child.once("exit", (code, signal) => {
        if (signal) {
          resolve(1);
          return;
        }

        resolve(code ?? 1);
      });
    });

    await cleanup();
    process.exit(Number(exitCode));
  } catch (error) {
    await cleanup();
    throw error;
  }
}

await main();
