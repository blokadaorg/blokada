import test from "node:test";
import assert from "node:assert/strict";

import {
  hasRunningWebDriverAgent,
  isHardResetRequested,
  ensurePatchedWebDriverAgent,
  findAutomationModeProcessIds,
  findWebDriverAgentProcessIds,
  hasInstalledDriver,
  patchWdaKeyboardPreferencesSource,
  parseInstalledDrivers,
  parseRunningProcesses,
  selectAutomationReuseStrategy
} from "../lib/appium-runtime.mjs";
import { mkdir, mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

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

test("findAutomationModeProcessIds selects automation mode processes only", () => {
  const processIds = findAutomationModeProcessIds(
    JSON.stringify({
      result: {
        runningProcesses: [
          { processIdentifier: 101, name: "SpringBoard" },
          { processIdentifier: 202, name: "AutomationModeUI" },
          {
            pid: 303,
            executable: "file:///System/Library/PrivateFrameworks/AutomationMode.framework/automationmode-writer"
          }
        ]
      }
    })
  );

  assert.deepEqual(processIds, [202, 303]);
});

test("patchWdaKeyboardPreferencesSource removes the default keyboard preference override", () => {
  const source = [
    "+ (void)setUp",
    "{",
    "  [FBDebugLogDelegateDecorator decorateXCTestLogger];",
    "  [FBConfiguration configureDefaultKeyboardPreferences];",
    "  [super setUp];",
    "}"
  ].join("\n");
  const replacement = [
    "  // Blokada: preserve current iOS keyboard preferences during Appium sessions.",
    "  // Appium's default WDA startup flips Auto-Correction and Predictive off.",
    "  // Preserve the device's current keyboard settings instead."
  ].join("\n");

  const patched = patchWdaKeyboardPreferencesSource(source, replacement);

  assert.equal(
    patched.includes("[FBConfiguration configureDefaultKeyboardPreferences];"),
    false
  );
  assert.equal(
    patched.includes("preserve current iOS keyboard preferences"),
    true
  );
});

test("patchWdaKeyboardPreferencesSource is idempotent", () => {
  const source = [
    "+ (void)setUp",
    "{",
    "  [FBDebugLogDelegateDecorator decorateXCTestLogger];",
    "  [FBConfiguration configureDefaultKeyboardPreferences];",
    "  [super setUp];",
    "}"
  ].join("\n");
  const replacement = [
    "  // Blokada: preserve current iOS keyboard preferences during Appium sessions.",
    "  // Appium's default WDA startup flips Auto-Correction and Predictive off.",
    "  // Preserve the device's current keyboard settings instead."
  ].join("\n");

  const patchedOnce = patchWdaKeyboardPreferencesSource(source, replacement);
  const patchedTwice = patchWdaKeyboardPreferencesSource(patchedOnce, replacement);

  assert.equal(patchedTwice, patchedOnce);
});

test("hasRunningWebDriverAgent detects presence from process payload", () => {
  assert.equal(
    hasRunningWebDriverAgent(
      JSON.stringify({
        result: {
          runningProcesses: [
            { processIdentifier: 101, name: "SpringBoard" },
            { processIdentifier: 202, name: "WebDriverAgentRunner-Runner" }
          ]
        }
      })
    ),
    true
  );
  assert.equal(
    hasRunningWebDriverAgent(
      JSON.stringify({
        result: {
          runningProcesses: [{ processIdentifier: 101, name: "SpringBoard" }]
        }
      })
    ),
    false
  );
});

test("findWebDriverAgentProcessIds excludes AutomationMode-only processes", () => {
  const processIds = findWebDriverAgentProcessIds(
    JSON.stringify({
      result: {
        runningProcesses: [
          { processIdentifier: 202, name: "AutomationModeUI" },
          {
            pid: 303,
            executable: "file:///System/Library/PrivateFrameworks/AutomationMode.framework/automationmode-writer"
          }
        ]
      }
    })
  );

  assert.deepEqual(processIds, []);
});

test("isHardResetRequested honors explicit env flags only", () => {
  assert.equal(isHardResetRequested({}), false);
  assert.equal(isHardResetRequested({ APPIUM_WDA_HARD_RESET: "1" }), true);
  assert.equal(isHardResetRequested({ APPIUM_WDA_HARD_RESET: "0" }), false);
});

test("selectAutomationReuseStrategy prefers reuse before fresh startup", () => {
  assert.equal(
    selectAutomationReuseStrategy({
      appiumServerReady: true,
      hardResetRequested: false,
      runningWebDriverAgent: true
    }),
    "reuse-appium-server"
  );
  assert.equal(
    selectAutomationReuseStrategy({
      appiumServerReady: false,
      hardResetRequested: false,
      runningWebDriverAgent: true
    }),
    "reuse-webdriveragent"
  );
  assert.equal(
    selectAutomationReuseStrategy({
      appiumServerReady: false,
      hardResetRequested: false,
      runningWebDriverAgent: false
    }),
    "fresh-start"
  );
  assert.equal(
    selectAutomationReuseStrategy({
      appiumServerReady: true,
      hardResetRequested: true,
      runningWebDriverAgent: true
    }),
    "hard-reset"
  );
});

test("ensurePatchedWebDriverAgent rewrites the repo-local WDA source in place", async () => {
  const tempDir = await mkdtemp(join(tmpdir(), "appium-wda-test-"));
  const sourcePath = join(
    tempDir,
    "node_modules",
    "appium-xcuitest-driver",
    "node_modules",
    "appium-webdriveragent",
    "WebDriverAgentRunner",
    "UITestingUITests.m"
  );
  await mkdir(
    join(
      tempDir,
      "node_modules",
      "appium-xcuitest-driver",
      "node_modules",
      "appium-webdriveragent",
      "WebDriverAgentRunner"
    ),
    { recursive: true }
  );

  await writeFile(
    sourcePath,
    [
      "+ (void)setUp",
      "{",
      "  [FBConfiguration configureDefaultKeyboardPreferences];",
      "}"
    ].join("\n")
  );

  const patched = await ensurePatchedWebDriverAgent({
    env: { APPIUM_HOME: tempDir },
    log: () => {}
  });

  assert.equal(patched, true);
  const source = await readFile(sourcePath, "utf8");
  assert.equal(
    source.includes("[FBConfiguration configureDefaultKeyboardPreferences];"),
    false
  );
});
