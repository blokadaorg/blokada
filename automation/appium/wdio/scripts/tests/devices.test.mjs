import test from "node:test";
import assert from "node:assert/strict";

import {
  filterConnectedDevices,
  parseDevices,
  pickNamedDevice,
  resolveTargetDevice,
  shellQuote
} from "../../../../shared/lib/devices.mjs";

test("parseDevices extracts xcdevice rows", () => {
  const output = [
    "Test iPhone [FACEFEED-1111222233334444] (26.3.1) (Connected)",
    "Test iPad [DEADC0DE-5555666677778888] (18.4)"
  ].join("\n");

  const devices = parseDevices(
    output,
    /^(?<name>.+?)\s+\[(?<udid>[0-9A-F-]{4,})\]\s+\((?<os>.+?)\)(?:\s+\((?<state>.+)\))?$/i
  );

  assert.equal(devices.length, 2);
  assert.equal(devices[0].name, "Test iPhone");
  assert.equal(devices[0].udid, "FACEFEED-1111222233334444");
});

test("filterConnectedDevices keeps connected or state-less devices", () => {
  const devices = filterConnectedDevices([
    { name: "Test iPhone", state: "Connected", modelName: "iPhone 17 Pro" },
    { name: "Offline", state: "Disconnected", modelName: "iPhone 17 Pro" },
    { name: "Sample Watch", state: "Connected", os: "watchOS 11.0" },
    { name: "Sim", state: "Connected", simulator: true, modelName: "iPhone 17 Pro" },
    { name: "Unavailable", state: "Unavailable", available: false, modelName: "iPhone 17 Pro" },
    { name: "Unknown", state: "", modelName: "iPad Air 13-inch (M3)" }
  ]);

  assert.deepEqual(
    devices.map((device) => device.name),
    ["Test iPhone", "Unknown"]
  );
});

test("pickNamedDevice supports exact and partial matches", () => {
  const devices = [
    { name: "Test iPhone", udid: "1" },
    { name: "Test iPad", udid: "2" }
  ];

  assert.equal(pickNamedDevice(devices, "Test iPhone")?.udid, "1");
  assert.equal(pickNamedDevice(devices, "ipad")?.udid, "2");
});

test("shellQuote escapes apostrophes", () => {
  assert.equal(shellQuote("Owner's iPhone"), "'Owner'\\''s iPhone'");
});

test("resolveTargetDevice honors IOS_UDID even when discovery is empty", async () => {
  const device = await resolveTargetDevice({
    devices: [],
    requestedUdid: "FACEFEED-1111222233334444",
    requestedName: "Example iPhone"
  });

  assert.deepEqual(device, {
    name: "Example iPhone",
    os: "unknown",
    udid: "FACEFEED-1111222233334444",
    state: ""
  });
});

test("resolveTargetDevice auto-selects the first device when requested", async () => {
  const devices = [
    { name: "Example iPhone", os: "26.3.1", udid: "1", state: "Connected" },
    { name: "Example iPad", os: "26.3.1", udid: "2", state: "Connected" }
  ];
  let prompted = false;

  const device = await resolveTargetDevice({
    devices,
    interactive: true,
    autoSelectFirst: true,
    prompt: async () => {
      prompted = true;
      throw new Error("prompt should not be called");
    }
  });

  assert.equal(prompted, false);
  assert.deepEqual(device, devices[0]);
});

test("resolveTargetDevice ignores simulators when auto-selecting the first device", async () => {
  const device = await resolveTargetDevice({
    autoSelectFirst: true,
    devices: filterConnectedDevices([
      { name: "Sim", os: "iOS 26.0", state: "", simulator: true, modelName: "iPhone 17 Pro" },
      { name: "Example iPhone", os: "26.3.1", state: "Connected", udid: "phone-udid", modelName: "iPhone 17 Pro" }
    ]),
    interactive: true
  });

  assert.equal(device.name, "Example iPhone");
  assert.equal(device.udid, "phone-udid");
});

test("resolveTargetDevice prompts when multiple physical devices are connected", async () => {
  let prompted = false;

  await assert.rejects(
    resolveTargetDevice({
      devices: filterConnectedDevices([
        { name: "Example iPad", os: "26.3.1", state: "Connected", udid: "ipad-udid", modelName: "iPad Air 11-inch (M3)" },
        { name: "Example iPhone", os: "26.3.1", state: "Connected", udid: "phone-udid", modelName: "iPhone 17 Pro" }
      ]),
      interactive: true,
      autoSelectFirst: false,
      prompt: async () => {
        prompted = true;
        throw new Error("prompted");
      }
    }),
    /prompted/
  );

  assert.equal(prompted, true);
});

test("resolveTargetDevice prefers an iphone when auto-selecting", async () => {
  const device = await resolveTargetDevice({
    devices: filterConnectedDevices([
      { name: "Example iPad", os: "26.3.1", state: "Connected", udid: "ipad-udid", modelName: "iPad Air 11-inch (M3)" },
      { name: "Example iPhone", os: "26.3.1", state: "Connected", udid: "phone-udid", modelName: "iPhone 17 Pro" }
    ]),
    interactive: false
  });

  assert.equal(device.name, "Example iPhone");
  assert.equal(device.udid, "phone-udid");
});
