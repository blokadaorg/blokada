import test from "node:test";
import assert from "node:assert/strict";

import {
  findWebDriverAgentProcessIds,
  hasInstalledDriver,
  parseInstalledDrivers,
  parseRunningProcesses
} from "../lib/appium-runtime.mjs";

test("parseInstalledDrivers returns installed entries only", () => {
  const installed = parseInstalledDrivers(
    JSON.stringify({
      xcuitest: { installed: true },
      uiautomator2: { installed: false }
    })
  );

  assert.deepEqual(installed, [["xcuitest", { installed: true }]]);
});

test("hasInstalledDriver detects xcuitest", () => {
  assert.equal(
    hasInstalledDriver(JSON.stringify({ xcuitest: { installed: true } })),
    true
  );
  assert.equal(
    hasInstalledDriver(JSON.stringify({ xcuitest: { installed: false } })),
    false
  );
});

test("parseRunningProcesses reads devicectl json payloads", () => {
  const runningProcesses = parseRunningProcesses(
    JSON.stringify({
      result: {
        runningProcesses: [
          { processIdentifier: 101, name: "SpringBoard" },
          { processIdentifier: 202, name: "WebDriverAgentRunner-Runner" }
        ]
      }
    })
  );

  assert.deepEqual(runningProcesses, [
    { processIdentifier: 101, name: "SpringBoard" },
    { processIdentifier: 202, name: "WebDriverAgentRunner-Runner" }
  ]);
});

test("findWebDriverAgentProcessIds selects WDA processes only", () => {
  const processIds = findWebDriverAgentProcessIds(
    JSON.stringify({
      result: {
        runningProcesses: [
          { processIdentifier: 101, name: "SpringBoard" },
          { processIdentifier: 202, name: "WebDriverAgentRunner-Runner" },
          { pid: 303, executable: { name: "WebDriverAgentRunner" } }
        ]
      }
    })
  );

  assert.deepEqual(processIds, [202, 303]);
});
