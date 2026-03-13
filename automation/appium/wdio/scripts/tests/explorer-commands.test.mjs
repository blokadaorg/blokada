import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { runExplorerCommand } from "../lib/explorer-commands.mjs";

function makeDriver() {
  return {
    async execute(command, payload) {
      if (command === "mobile: queryAppState") {
        return 4;
      }
      if (command === "mobile: launchApp") {
        return undefined;
      }
      if (command === "mobile: terminateApp") {
        return undefined;
      }
      throw new Error(`Unexpected execute call: ${command} ${JSON.stringify(payload)}`);
    },
    async getPageSource() {
      return [
        '<XCUIElementTypeApplication name="Dev" label="Dev">',
        '<XCUIElementTypeButton name="automation.power_toggle" value="active"/>',
        '<XCUIElementTypeStaticText name="Privacy Pulse" label="Privacy Pulse"/>',
        "</XCUIElementTypeApplication>"
      ].join("");
    },
    async saveScreenshot(path) {
      await readFile(new URL(import.meta.url)).catch(() => undefined);
      return path;
    },
    async activateApp() {
      return undefined;
    },
    async $(selector) {
      return {
        async isExisting() {
          return selector === "~Privacy Pulse";
        },
        async getAttribute(name) {
          return `${selector}:${name}`;
        },
        async click() {
          return undefined;
        },
        async setValue() {
          return undefined;
        },
        async waitForExist() {
          return undefined;
        }
      };
    }
  };
}

test("session.status reports app state", async () => {
  const result = await runExplorerCommand(
    makeDriver(),
    { bundleId: "net.blocka.app", deviceName: "Test iPhone", outputDir: tmpdir(), udid: "abc" },
    "session.status"
  );

  assert.equal(result.result.appState.label, "running-foreground");
  assert.equal(result.result.deviceName, "Test iPhone");
});

test("ui.summary returns a lightweight app-state and label summary", async () => {
  const result = await runExplorerCommand(
    makeDriver(),
    { bundleId: "net.blocka.app", deviceName: "Test iPhone", outputDir: tmpdir(), udid: "abc" },
    "ui.summary",
    { limit: 3 }
  );

  assert.equal(result.result.appState.label, "running-foreground");
  assert.deepEqual(result.result.labels, ["Dev", "Privacy Pulse", "automation.power_toggle"]);
});

test("ui.inspect reuses one source fetch and returns bounded summaries", async () => {
  const outputDir = await mkdtemp(join(tmpdir(), "appium-inspect-"));
  const driver = makeDriver();
  let sourceReads = 0;
  driver.getPageSource = async () => {
    sourceReads += 1;
    return [
      '<XCUIElementTypeApplication name="Dev" label="Dev">',
      '<XCUIElementTypeButton name="automation.power_toggle" value="active"/>',
      '<XCUIElementTypeStaticText name="Privacy Pulse" label="Privacy Pulse"/>',
      "</XCUIElementTypeApplication>"
    ].join("");
  };

  const result = await runExplorerCommand(
    driver,
    { bundleId: "net.blocka.app", deviceName: "Test iPhone", outputDir, udid: "abc" },
    "ui.inspect",
    { labels: true, tree: true, source: true, limit: 5, name: "inspect" }
  );

  assert.equal(sourceReads, 1);
  assert.deepEqual(result.result.labels, ["Dev", "Privacy Pulse", "automation.power_toggle", "active"]);
  assert.ok(Array.isArray(result.result.tree));
  assert.ok(result.result.artifacts.source.endsWith("inspect.xml"));
});

test("ui.exists and ui.attr use structured args", async () => {
  const context = { bundleId: "net.blocka.app", deviceName: "Test iPhone", outputDir: tmpdir(), udid: "abc" };
  const driver = makeDriver();

  const exists = await runExplorerCommand(driver, context, "ui.exists", {
    selector: "~Privacy Pulse"
  });
  const attr = await runExplorerCommand(driver, context, "ui.attr", {
    selector: "~Privacy Pulse",
    name: "value"
  });

  assert.equal(exists.result, true);
  assert.equal(attr.result, "~Privacy Pulse:value");
});
