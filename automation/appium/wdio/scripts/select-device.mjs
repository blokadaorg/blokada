#!/usr/bin/env node

import { execSync } from "node:child_process";
import readline from "node:readline";

const XCDEVICE_REGEX = /^(?<name>.+?)\s+\[(?<udid>[0-9A-F-]{4,})\]\s+\((?<os>.+?)\)(?:\s+\((?<state>.+)\))?$/i;
const XCTRACE_REGEX =
  /^\s*(?<name>.+?)\s*\((?<os>[^()]+)\)\s*\((?<udid>[0-9A-F-]{4,})\)(?:\s*\((?<state>[^()]+)\))?/i;

function parseDevices(output, regex) {
  const devices = [];
  const seen = new Set();

  for (const line of output.split("\n")) {
    const match = line.match(regex);
    if (!match?.groups) continue;
    const { name, os, udid, state } = match.groups;
    if (!udid || seen.has(udid)) continue;
    seen.add(udid);
    devices.push({
      name: name.trim(),
      os: os.trim(),
      udid: udid.trim(),
      state: state?.trim() ?? ""
    });
  }

  return devices;
}

function readDeviceList() {
  try {
    const xcdevice = execSync("xcrun xcdevice list 2>/dev/null", {
      encoding: "utf8"
    });
    const parsed = parseDevices(xcdevice, XCDEVICE_REGEX);
    if (parsed.length > 0) {
      return parsed;
    }
  } catch (error) {
    // ignore and fall back to xctrace
  }

  try {
    const result = execSync("xcrun xctrace list devices 2>/dev/null", {
      encoding: "utf8"
    });
    return parseDevices(result, XCTRACE_REGEX);
  } catch (error) {
    return [];
  }
}

async function promptUser(devices) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stderr
  });

  try {
    rl.write("Select iOS device:\n");
    devices.forEach((device, index) => {
      const state = device.state ? ` (${device.state})` : "";
      rl.write(
        `  [${index + 1}] ${device.name} – iOS ${device.os}${state}\n`
      );
    });
    rl.write("Enter choice number: ");

    const answer = await new Promise((resolve) => rl.question("", resolve));
    const idx = Number.parseInt(answer, 10) - 1;
    if (Number.isNaN(idx) || idx < 0 || idx >= devices.length) {
      throw new Error("Invalid selection.");
    }
    return devices[idx];
  } finally {
    rl.close();
  }
}

async function main() {
  const devices = readDeviceList().filter((device) => {
    const state = (device.state ?? "").toLowerCase();
    return state.includes("connect") || state === "";
  });
  const requestedName = (process.env.IOS_DEVICE_NAME ?? "").trim().toLowerCase();
  const autoSelectFirst =
    (process.env.IOS_AUTO_SELECT_FIRST ?? "").trim() === "1" ||
    (process.env.CI ?? "").trim() === "true";

  if (devices.length === 0) {
    console.error(
      "No physical iOS devices detected. Set IOS_UDID manually and retry."
    );
    process.exit(1);
  }

  if (requestedName) {
    const exact = devices.find(
      (device) => device.name.toLowerCase() === requestedName
    );
    const partial = devices.find((device) =>
      device.name.toLowerCase().includes(requestedName)
    );
    const chosen = exact ?? partial;
    if (!chosen) {
      console.error(
        `No connected device matches IOS_DEVICE_NAME='${process.env.IOS_DEVICE_NAME}'.`
      );
      process.exit(1);
    }
    console.error(
      `Using device ${chosen.name} (iOS ${chosen.os}) – ${chosen.udid}`
    );
    process.stdout.write(chosen.udid);
    return;
  }

  if (devices.length === 1 || !process.stdin.isTTY || autoSelectFirst) {
    console.error(
      `Using device ${devices[0].name} (iOS ${devices[0].os}) – ${devices[0].udid}`
    );
    process.stdout.write(devices[0].udid);
    return;
  }

  try {
    const device = await promptUser(devices);
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
