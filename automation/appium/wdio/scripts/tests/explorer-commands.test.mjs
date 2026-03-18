import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { runExplorerCommand } from "../lib/explorer-commands.mjs";

const PAGE_SOURCES = {
  "net.blocka.app": [
    '<XCUIElementTypeApplication name="Dev" label="Dev">',
    '<XCUIElementTypeButton name="automation.power_toggle" value="1" visible="true" hittable="true"/>',
    '<XCUIElementTypeStaticText name="Privacy Pulse" label="Privacy Pulse" visible="true"/>',
    "</XCUIElementTypeApplication>"
  ].join(""),
  "net.blocka.app.family": [
    '<XCUIElementTypeApplication name="FamilyDev" label="FamilyDev">',
    '<XCUIElementTypeStaticText name="Families" label="Families" visible="true"/>',
    "</XCUIElementTypeApplication>"
  ].join(""),
  "com.apple.Preferences": [
    '<XCUIElementTypeApplication name="Settings" label="Settings">',
    '<XCUIElementTypeNavigationBar name="General" label="General">',
    '<XCUIElementTypeButton name="Settings" label="Settings" visible="true"/>',
    "</XCUIElementTypeNavigationBar>",
    '<XCUIElementTypeSearchField name="Search" label="Search" value="" visible="true" hittable="true"/>',
    '<XCUIElementTypeCell name="Keyboard" label="Keyboard" visible="true"/>',
    '<XCUIElementTypeSwitch name="Auto-Correction" label="Auto-Correction" value="1" visible="true" hittable="true"/>',
    "</XCUIElementTypeApplication>"
  ].join("")
};

function makeElement(selector, calls, overrides = {}) {
  const attributes = new Map(Object.entries(overrides.attributes ?? {}));
  return {
    async isExisting() {
      return overrides.exists ?? true;
    },
    async isDisplayed() {
      return overrides.displayed ?? true;
    },
    async getAttribute(name) {
      if (attributes.has(name)) {
        return attributes.get(name);
      }
      return `${selector}:${name}`;
    },
    async click() {
      calls.push({ type: "element.click", selector });
      return undefined;
    },
    async setValue(value) {
      calls.push({ type: "element.setValue", selector, value });
      attributes.set("value", value);
      return undefined;
    },
    async clearValue() {
      calls.push({ type: "element.clearValue", selector });
      attributes.set("value", "");
      return undefined;
    },
    async waitForExist() {
      calls.push({ type: "element.waitForExist", selector });
      return undefined;
    }
  };
}

function makeDriver({
  activeAppInfoSequence,
  activeAppInfoUnsupported = false,
  appStates = {},
  autoSwitchActiveApp = true,
  currentBundleId = "net.blocka.app",
  pageSources = {}
} = {}) {
  const calls = [];
  const stateByBundleId = new Map([
    ["net.blocka.app", [4]],
    ["net.blocka.app.family", [4]],
    ["com.apple.Preferences", [4]]
  ]);

  for (const [bundleId, states] of Object.entries(appStates)) {
    stateByBundleId.set(bundleId, [...states]);
  }

  const sources = {
    ...PAGE_SOURCES,
    ...pageSources
  };
  const activeBundleSequence = activeAppInfoSequence ? [...activeAppInfoSequence] : undefined;
  const selectorState = new Map([
    [
      "~Privacy Pulse",
      makeElement("~Privacy Pulse", calls, {
        attributes: {
          label: "Privacy Pulse",
          name: "Privacy Pulse",
          value: "1",
          visible: "true",
          hittable: "true"
        }
      })
    ],
    [
      "//XCUIElementTypeSearchField[1]",
      makeElement("//XCUIElementTypeSearchField[1]", calls, {
        attributes: {
          type: "XCUIElementTypeSearchField",
          label: "Search",
          name: "Search",
          value: "",
          visible: "true",
          hittable: "true"
        }
      })
    ],
    [
      "//XCUIElementTypeNavigationBar[1]/XCUIElementTypeButton[1]",
      makeElement("//XCUIElementTypeNavigationBar[1]/XCUIElementTypeButton[1]", calls, {
        attributes: {
          label: "Settings",
          name: "Settings",
          visible: "true",
          hittable: "true"
        }
      })
    ],
    [
      "~Auto-Correction",
      makeElement("~Auto-Correction", calls, {
        attributes: {
          label: "Auto-Correction",
          name: "Auto-Correction",
          value: "1",
          visible: "true",
          hittable: "true"
        }
      })
    ]
  ]);

  return {
    calls,
    async execute(command, payload) {
      calls.push({ type: "execute", command, payload });
      if (command === "mobile: queryAppState") {
        const sequence = stateByBundleId.get(payload.bundleId) ?? [4];
        const next = sequence.length > 1 ? sequence.shift() : sequence[0];
        stateByBundleId.set(payload.bundleId, sequence);
        return next;
      }
      if (command === "mobile: activeAppInfo") {
        if (activeAppInfoUnsupported) {
          throw new Error("activeAppInfo unsupported");
        }
        if (activeBundleSequence) {
          const bundleId =
            activeBundleSequence.length > 1 ? activeBundleSequence.shift() : activeBundleSequence[0];
          return { bundleId };
        }
        return { bundleId: currentBundleId };
      }
      if (command === "mobile: launchApp") {
        if (autoSwitchActiveApp) {
          currentBundleId = payload.bundleId;
        }
        return undefined;
      }
      if (command === "mobile: terminateApp") {
        return undefined;
      }
      if (command === "mobile: swipe" || command === "mobile: scroll") {
        return undefined;
      }
      throw new Error(`Unexpected execute call: ${command} ${JSON.stringify(payload)}`);
    },
    async getPageSource() {
      return sources[currentBundleId] ?? PAGE_SOURCES["net.blocka.app"];
    },
    async saveScreenshot(path) {
      await readFile(new URL(import.meta.url)).catch(() => undefined);
      return path;
    },
    async activateApp(bundleId) {
      calls.push({ type: "activateApp", bundleId });
      if (autoSwitchActiveApp) {
        currentBundleId = bundleId;
      }
      return undefined;
    },
    async back() {
      calls.push({ type: "driver.back" });
      return undefined;
    },
    async $(selector) {
      if (!selectorState.has(selector)) {
        selectorState.set(selector, makeElement(selector, calls));
      }
      return selectorState.get(selector);
    }
  };
}

test("session.status reports app state and active app info", async () => {
  const result = await runExplorerCommand(
    makeDriver(),
    { bundleId: "net.blocka.app", deviceName: "Test iPhone", outputDir: tmpdir(), udid: "abc" },
    "session.status"
  );

  assert.equal(result.result.appState.label, "running-foreground");
  assert.equal(result.result.activeTarget, "six");
  assert.equal(result.result.deviceName, "Test iPhone");
  assert.equal(result.result.activeApp.bundleId, "net.blocka.app");
  assert.deepEqual(
    result.result.targets.map((target) => target.target),
    ["six", "family", "settings"]
  );
});

test("ui.summary reports the verified foreground target and app identity", async () => {
  const result = await runExplorerCommand(
    makeDriver(),
    { bundleId: "net.blocka.app", deviceName: "Test iPhone", outputDir: tmpdir(), udid: "abc" },
    "ui.summary",
    { limit: 3 }
  );

  assert.equal(result.result.target, "six");
  assert.equal(result.result.bundleId, "net.blocka.app");
  assert.equal(result.result.appState.label, "running-foreground");
  assert.equal(result.result.activeApp.bundleId, "net.blocka.app");
  assert.equal(result.result.appIdentity.label, "Dev");
  assert.deepEqual(result.result.labels, ["Dev", "Privacy Pulse", "automation.power_toggle"]);
  assert.equal(result.result.targetVerified, true);
});

test("ui.summary can filter labels by matchText for focused navigation", async () => {
  const result = await runExplorerCommand(
    makeDriver({
      currentBundleId: "com.apple.Preferences"
    }),
    { bundleId: "net.blocka.app", deviceName: "Test iPhone", outputDir: tmpdir(), udid: "abc" },
    "ui.summary",
    { limit: 10, matchText: "key" }
  );

  assert.equal(result.result.target, "settings");
  assert.deepEqual(result.result.labels, ["Keyboard"]);
});

test("app.activate can switch to Settings by target alias", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver();

  const result = await runExplorerCommand(driver, context, "app.activate", {
    target: "settings"
  });

  assert.equal(result.result.target, "settings");
  assert.equal(result.result.bundleId, "com.apple.Preferences");
  assert.equal(result.result.activeApp.bundleId, "com.apple.Preferences");

  const summary = await runExplorerCommand(driver, context, "ui.summary", {});
  assert.equal(summary.result.target, "settings");
  assert.equal(summary.result.bundleId, "com.apple.Preferences");
  assert.equal(summary.result.appIdentity.label, "Settings");
});

test("app.activate waits for verified foreground identity to catch up", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver({
    activeAppInfoSequence: ["net.blocka.app", "com.apple.Preferences"]
  });

  const result = await runExplorerCommand(driver, context, "app.activate", {
    target: "settings"
  });

  assert.equal(result.result.target, "settings");
  assert.equal(result.result.activeApp.bundleId, "com.apple.Preferences");
});

test("app.activate falls back to app state when activeAppInfo is unavailable", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver({
    activeAppInfoUnsupported: true,
    currentBundleId: "com.apple.Preferences"
  });

  const result = await runExplorerCommand(driver, context, "app.activate", {
    target: "settings"
  });

  assert.equal(result.result.target, "settings");
  assert.equal(result.result.bundleId, "com.apple.Preferences");
  assert.equal(result.result.targetVerified, false);
});

test("app.activate can switch to Family by target alias", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver({
    currentBundleId: "net.blocka.app.family"
  });

  const result = await runExplorerCommand(driver, context, "app.activate", {
    target: "family"
  });

  assert.equal(result.result.target, "family");
  assert.equal(result.result.bundleId, "net.blocka.app.family");

  const summary = await runExplorerCommand(driver, context, "ui.summary", {});
  assert.equal(summary.result.target, "family");
  assert.equal(summary.result.bundleId, "net.blocka.app.family");
  assert.equal(summary.result.appIdentity.label, "FamilyDev");
});

test("app.activate can switch to Six explicitly in a family session", async () => {
  const context = {
    bundleId: "net.blocka.app.family",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver({
    currentBundleId: "net.blocka.app.family"
  });

  const result = await runExplorerCommand(driver, context, "app.activate", {
    target: "six"
  });

  assert.equal(result.result.target, "six");
  assert.equal(result.result.bundleId, "net.blocka.app");

  const summary = await runExplorerCommand(driver, context, "ui.summary", {});
  assert.equal(summary.result.target, "six");
  assert.equal(summary.result.bundleId, "net.blocka.app");
  assert.equal(summary.result.appIdentity.label, "Dev");
});

test("app.activate fails when foreground verification disagrees with app state", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver({
    activeAppInfoSequence: ["net.blocka.app"],
    autoSwitchActiveApp: false
  });

  await assert.rejects(
    runExplorerCommand(driver, context, "app.activate", { target: "settings" }),
    /Activate foreground verification failed/
  );

  const summary = await runExplorerCommand(driver, context, "ui.summary", {});
  assert.equal(summary.result.target, "six");
  assert.equal(summary.result.bundleId, "net.blocka.app");
});

test("app.state can inspect explicit targets without changing the active app", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver();

  await runExplorerCommand(driver, context, "app.activate", { target: "settings" });
  const sixState = await runExplorerCommand(driver, context, "app.state", {
    target: "six"
  });
  const status = await runExplorerCommand(driver, context, "session.status");

  assert.equal(sixState.result.target, "six");
  assert.equal(sixState.result.bundleId, "net.blocka.app");
  assert.equal(status.result.activeTarget, "settings");
});

test("app.state defaults to the configured session app even after switching targets", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver();

  await runExplorerCommand(driver, context, "app.activate", { target: "settings" });
  const result = await runExplorerCommand(driver, context, "app.state");

  assert.equal(result.result.target, "six");
  assert.equal(result.result.bundleId, "net.blocka.app");
});

test("app.state defaults to the configured session app when target is omitted", async () => {
  const context = {
    bundleId: "net.blocka.app.family",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };

  const result = await runExplorerCommand(makeDriver(), context, "app.state");

  assert.equal(result.result.target, "family");
  assert.equal(result.result.bundleId, "net.blocka.app.family");
});

test("app.terminate defaults to the configured session app even after switching targets", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver();

  await runExplorerCommand(driver, context, "app.activate", { target: "settings" });
  const result = await runExplorerCommand(driver, context, "app.terminate");

  assert.equal(result.result.target, "six");
  assert.equal(result.result.bundleId, "net.blocka.app");
  assert.deepEqual(
    driver.calls.filter((call) => call.type === "execute").slice(-2),
    [
      {
        type: "execute",
        command: "mobile: terminateApp",
        payload: { bundleId: "net.blocka.app" }
      },
      {
        type: "execute",
        command: "mobile: queryAppState",
        payload: { bundleId: "net.blocka.app" }
      }
    ]
  );
});

test("session.status follows the verified foreground app instead of stale context", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver({
    currentBundleId: "com.apple.Preferences"
  });

  const result = await runExplorerCommand(driver, context, "session.status");

  assert.equal(result.result.activeTarget, "settings");
  assert.equal(result.result.activeApp.bundleId, "com.apple.Preferences");
  assert.equal(result.result.appState.label, "running-foreground");
});

test("app.activate rejects removed blokada target alias", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };

  await assert.rejects(
    runExplorerCommand(makeDriver(), context, "app.activate", { target: "blokada" }),
    /Unknown app target 'blokada'. Use one of: six, family, settings/
  );
});

test("app.activate accepts advertised target aliases", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver({
    currentBundleId: "net.blocka.app.family"
  });

  const targets = await runExplorerCommand(driver, context, "app.targets");
  const family = targets.result.targets.find((target) => target.target === "family");

  assert.deepEqual(family.aliases, ["family", "blokada-family"]);

  const result = await runExplorerCommand(driver, context, "app.activate", {
    target: "blokada-family"
  });

  assert.equal(result.result.target, "family");
  assert.equal(result.result.bundleId, "net.blocka.app.family");
});

test("ui.inspect reuses one source fetch and returns bounded summaries", async () => {
  const outputDir = await mkdtemp(join(tmpdir(), "appium-inspect-"));
  const driver = makeDriver();
  let sourceReads = 0;
  driver.getPageSource = async () => {
    sourceReads += 1;
    return PAGE_SOURCES["net.blocka.app"];
  };

  const result = await runExplorerCommand(
    driver,
    { bundleId: "net.blocka.app", deviceName: "Test iPhone", outputDir, udid: "abc" },
    "ui.inspect",
    { labels: true, tree: true, elements: true, source: true, limit: 5, name: "inspect" }
  );

  assert.equal(sourceReads, 1);
  assert.deepEqual(result.result.labels, ["Dev", "Privacy Pulse", "automation.power_toggle", "1"]);
  assert.ok(Array.isArray(result.result.tree));
  assert.ok(Array.isArray(result.result.elements));
  assert.equal(result.result.elements[0].type, "XCUIElementTypeApplication");
  assert.ok(result.result.artifacts.source.endsWith("inspect.xml"));
});

test("ui.inspect returns elements when labels and tree are disabled", async () => {
  const result = await runExplorerCommand(
    makeDriver(),
    { bundleId: "net.blocka.app", deviceName: "Test iPhone", outputDir: tmpdir(), udid: "abc" },
    "ui.inspect",
    { labels: false, tree: false, elements: true, limit: 5 }
  );

  assert.ok(Array.isArray(result.result.elements));
  assert.equal(result.result.elements[0].type, "XCUIElementTypeApplication");
});

test("ui.inspect can compact and filter Settings output to matching interactive nodes", async () => {
  const outputDir = await mkdtemp(join(tmpdir(), "appium-inspect-filtered-"));
  const settingsSource = [
    '<XCUIElementTypeApplication name="Settings" label="Settings">',
    '<XCUIElementTypeWindow visible="true">',
    '<XCUIElementTypeOther visible="true">',
    '<XCUIElementTypeNavigationBar name="General" label="General">',
    '<XCUIElementTypeButton name="Settings" label="Settings" visible="true" hittable="true"/>',
    "</XCUIElementTypeNavigationBar>",
    '<XCUIElementTypeOther visible="true">',
    '<XCUIElementTypeCell name="Keyboard" label="Keyboard" visible="true" hittable="true"/>',
    '<XCUIElementTypeSwitch name="Auto-Correction" label="Auto-Correction" value="1" visible="true" hittable="true"/>',
    '<XCUIElementTypeStaticText name="Background App Refresh" label="Background App Refresh" visible="true"/>',
    "</XCUIElementTypeOther>",
    "</XCUIElementTypeOther>",
    "</XCUIElementTypeWindow>",
    "</XCUIElementTypeApplication>"
  ].join("");

  const result = await runExplorerCommand(
    makeDriver({
      currentBundleId: "com.apple.Preferences",
      pageSources: {
        "com.apple.Preferences": settingsSource
      }
    }),
    { bundleId: "net.blocka.app", deviceName: "Test iPhone", outputDir, udid: "abc" },
    "ui.inspect",
    {
      labels: true,
      tree: true,
      elements: true,
      compact: true,
      interactiveOnly: true,
      matchText: "key",
      limit: 10
    }
  );

  assert.deepEqual(result.result.labels, ["Keyboard"]);
  assert.deepEqual(result.result.tree, [
    'XCUIElementTypeApplication name="Settings" label="Settings"',
    '      XCUIElementTypeNavigationBar name="General" label="General"',
    '        XCUIElementTypeCell name="Keyboard" label="Keyboard" visible="true"'
  ]);
  assert.deepEqual(result.result.elements, [
    {
      type: "XCUIElementTypeCell",
      name: "Keyboard",
      label: "Keyboard",
      visible: "true",
      hittable: "true"
    }
  ]);
});

test("ui.summary and ui.inspect can ignore hidden matches with visibleOnly", async () => {
  const hiddenVpnSource = [
    '<XCUIElementTypeApplication name="Settings" label="Settings" visible="true">',
    '<XCUIElementTypeCell name="VPN" label="VPN" visible="false" hittable="false">',
    '<XCUIElementTypeSwitch name="com.apple.settings.vpn" label="VPN" value="0" visible="false" hittable="false"/>',
    "</XCUIElementTypeCell>",
    '<XCUIElementTypeCell name="Keyboard" label="Keyboard" visible="true" hittable="true"/>',
    "</XCUIElementTypeApplication>"
  ].join("");
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver({
    currentBundleId: "com.apple.Preferences",
    pageSources: {
      "com.apple.Preferences": hiddenVpnSource
    }
  });

  const summary = await runExplorerCommand(driver, context, "ui.summary", {
    limit: 10,
    matchText: "vpn",
    visibleOnly: true
  });
  const inspect = await runExplorerCommand(driver, context, "ui.inspect", {
    limit: 10,
    compact: true,
    interactiveOnly: true,
    visibleOnly: true,
    matchText: "vpn"
  });

  assert.deepEqual(summary.result.labels, []);
  assert.deepEqual(inspect.result.labels, []);
  assert.deepEqual(inspect.result.tree, []);
  assert.deepEqual(inspect.result.elements, []);
});

test("ui.read normalizes common element attributes", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver();

  const result = await runExplorerCommand(driver, context, "ui.read", {
    selector: "~Auto-Correction"
  });

  assert.equal(result.result.selector, "~Auto-Correction");
  assert.equal(result.result.value, "1");
  assert.equal(result.result.booleanValue, true);
  assert.equal(result.result.hittableBoolean, true);
});

test("ui.search focuses the first search field and types text", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver({
    currentBundleId: "com.apple.Preferences"
  });

  const result = await runExplorerCommand(driver, context, "ui.search", {
    text: "keyboard"
  });

  assert.equal(result.result.selector, "//XCUIElementTypeSearchField[1]");
  assert.equal(result.result.text, "keyboard");
  assert.deepEqual(
    driver.calls.filter((call) => call.type === "element.setValue").map((call) => call.value),
    ["keyboard"]
  );
});

test("ui.back uses driver navigation by default", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver({
    currentBundleId: "com.apple.Preferences"
  });

  const result = await runExplorerCommand(driver, context, "ui.back", {});

  assert.equal(result.result, "driver.back");
  assert.equal(driver.calls.at(-1).type, "driver.back");
});

test("ui.swipe and ui.scroll forward the requested direction", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver();

  const swipe = await runExplorerCommand(driver, context, "ui.swipe", {
    direction: "left"
  });
  const scroll = await runExplorerCommand(driver, context, "ui.scroll", {
    direction: "down"
  });

  assert.equal(swipe.result, "left");
  assert.equal(scroll.result, "down");
  assert.deepEqual(
    driver.calls
      .filter((call) => call.type === "execute" && call.command.startsWith("mobile: "))
      .slice(-2)
      .map((call) => ({ command: call.command, payload: call.payload })),
    [
      { command: "mobile: swipe", payload: { direction: "left" } },
      { command: "mobile: scroll", payload: { direction: "down" } }
    ]
  );
});

test("ui.exists and ui.attr use structured args", async () => {
  const context = {
    bundleId: "net.blocka.app",
    deviceName: "Test iPhone",
    outputDir: tmpdir(),
    udid: "abc"
  };
  const driver = makeDriver();

  const exists = await runExplorerCommand(driver, context, "ui.exists", {
    selector: "~Privacy Pulse"
  });
  const attr = await runExplorerCommand(driver, context, "ui.attr", {
    selector: "~Privacy Pulse",
    name: "value"
  });

  assert.equal(exists.result, true);
  assert.equal(attr.result, "1");
});
