#!/usr/bin/env node

import { createInterface } from "node:readline";
import process from "node:process";

import { remote } from "webdriverio";

import {
  createManagedAppiumRuntime
} from "./lib/appium-runtime.mjs";
import {
  buildCapabilities,
  getRemoteOptions
} from "./lib/capabilities.mjs";
import { resolveTargetDevice } from "../../../shared/lib/devices.mjs";
import { runExplorerCommand } from "./lib/explorer-commands.mjs";
import { getProjectPaths } from "./lib/paths.mjs";
import {
  createAck,
  createDone,
  createError,
  createResult,
  parseJsonlRequest
} from "./lib/session-protocol.mjs";

function parseArgs(argv) {
  let jsonl = false;

  for (let index = 0; index < argv.length; index += 1) {
    const current = argv[index];
    if (current === "--jsonl") {
      jsonl = true;
      continue;
    }

    throw new Error(`Unknown argument '${current}'.`);
  }

  if (!jsonl) {
    throw new Error("Machine session mode requires --jsonl.");
  }

  return { jsonl };
}

function printJson(payload) {
  process.stdout.write(`${JSON.stringify(payload)}\n`);
}

async function runJsonlSession(driver, context) {
  const rl = createInterface({
    input: process.stdin,
    crlfDelay: Infinity,
    terminal: false
  });

  for await (const line of rl) {
    let request;

    try {
      request = parseJsonlRequest(line);
      if (!request) {
        continue;
      }

      printJson(createAck(request));
      const response = await runExplorerCommand(
        driver,
        context,
        request.command,
        request.args
      );
      printJson(createResult(request, response));

      if (request.command === "session.shutdown") {
        rl.close();
        printJson(createDone(request));
        break;
      }

      printJson(createDone(request));
    } catch (error) {
      printJson(createError(request, error));
      if (request?.command === "session.shutdown") {
        break;
      }
    }
  }
}

async function main() {
  parseArgs(process.argv.slice(2));
  const paths = getProjectPaths();
  const device = await resolveTargetDevice({ interactive: false });

  process.env.IOS_UDID = device.udid;
  process.env.IOS_DEVICE_NAME = device.name;
  process.env.APPIUM_HOME = paths.appiumHome;

  const runtime = await createManagedAppiumRuntime({
    deviceIdentifier: device.udid,
    log: console.error
  });
  let driver;
  const capabilities = buildCapabilities(process.env);
  const context = {
    bundleId: capabilities["appium:bundleId"],
    deviceName: device.name,
    outputDir: paths.outputDir,
    udid: device.udid
  };

  const cleanup = async () => {
    await runtime.softCleanup({
      deleteSession: async () => driver?.deleteSession()
    });
  };

  process.on("SIGINT", async () => {
    await cleanup();
    process.exit(130);
  });
  process.on("SIGTERM", async () => {
    await cleanup();
    process.exit(143);
  });

  try {
    driver = await remote(getRemoteOptions(process.env));
    await runJsonlSession(driver, context);
  } finally {
    await cleanup();
  }
}

await main();
