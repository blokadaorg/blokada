import test from "node:test";
import assert from "node:assert/strict";

import {
  filterConnectedDevices,
  parseDevices,
  pickNamedDevice,
  shellQuote
} from "../lib/devices.mjs";

test("parseDevices extracts xcdevice rows", () => {
  const output = [
    "Primary iPhone [00008150-00063C2A0A87801C] (26.3.1) (Connected)",
    "Primary iPad [00008110-0011223344556677] (18.4)"
  ].join("\n");

  const devices = parseDevices(
    output,
    /^(?<name>.+?)\s+\[(?<udid>[0-9A-F-]{4,})\]\s+\((?<os>.+?)\)(?:\s+\((?<state>.+)\))?$/i
  );

  assert.equal(devices.length, 2);
  assert.equal(devices[0].name, "Primary iPhone");
  assert.equal(devices[0].udid, "00008150-00063C2A0A87801C");
});

test("filterConnectedDevices keeps connected or state-less devices", () => {
  const devices = filterConnectedDevices([
    { name: "Primary iPhone", state: "Connected" },
    { name: "Offline", state: "Disconnected" },
    { name: "Apple Watch for Primary iPhone", state: "Connected", os: "watchOS 11.0" },
    { name: "Unknown", state: "" }
  ]);

  assert.deepEqual(
    devices.map((device) => device.name),
    ["Primary iPhone", "Unknown"]
  );
});

test("pickNamedDevice supports exact and partial matches", () => {
  const devices = [
    { name: "Primary iPhone", udid: "1" },
    { name: "Primary iPad", udid: "2" }
  ];

  assert.equal(pickNamedDevice(devices, "Primary iPhone")?.udid, "1");
  assert.equal(pickNamedDevice(devices, "ipad")?.udid, "2");
});

test("shellQuote escapes apostrophes", () => {
  assert.equal(shellQuote("Owner's iPhone"), "'Owner'\\''s iPhone'");
});
