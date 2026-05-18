import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { runAiExplorer } from "../lib/ai-explorer-runner.mjs";
import { deriveReportStatus } from "../lib/ai-explorer-report.mjs";

function makeFakeClient(options = {}) {
  const commands = [];
  let scrollPosition = 0;
  let summaryCount = 0;
  let screen = "home";
  const backReturnsHome = options.backReturnsHome !== false;
  const screenLabels = {
    advanced: ["automation.screen_advanced", "Advanced", "automation.filter_option.ads.primary"],
    home: [
      "automation.screen_home",
      "automation.power_toggle",
      "automation.home_privacy_pulse",
      "automation.home_advanced",
      "automation.home_settings",
      "Privacy Pulse",
      "Recent Activity",
      "Advanced"
    ],
    privacyPulse: [
      "automation.screen_privacy_pulse",
      "Privacy Pulse",
      "24 h",
      "7 d",
      "Blocked",
      "Allowed",
      "Recent Activity"
    ],
    settings: [
      "automation.screen_settings",
      "Settings",
      "automation.settings_exceptions",
      "automation.settings_weekly_report",
      "Notifications",
      "Version"
    ]
  };

  return {
    commands,
    start() {
      commands.push({ command: "start", args: {} });
    },
    async command(command, args = {}) {
      commands.push({ command, args });
      if (command === "session.status") {
        return {
          result: {
            deviceName: "Unit iPhone",
            udid: "unit-udid"
          }
        };
      }
      if (command === "ui.summary") {
        summaryCount += 1;
        return {
          result: {
            appState: { code: 4, label: "running-foreground" },
            bundleId: "net.blocka.app",
            labels: [`Tick ${summaryCount}`, ...screenLabels[screen], `Scroll ${scrollPosition}`],
            target: "six"
          }
        };
      }
      if (command === "ui.inspect") {
        return {
          result: {
            elements: [
              {
                label: screenLabels[screen][0],
                name: screenLabels[screen][0],
                type: "XCUIElementTypeButton",
                visible: true
              }
            ],
            labels: screenLabels[screen],
            tree: screenLabels[screen].map((label) => `XCUIElementTypeButton name="${label}"`)
          }
        };
      }
      if (command === "session.shutdown") {
        return { result: "shutdown" };
      }
      if (command === "ui.scroll") {
        scrollPosition += args.direction === "up" ? -1 : 1;
        return { result: args.direction };
      }
      if (command === "ui.exists") {
        const available = new Set([
          "~automation.home_privacy_pulse",
          "~automation.home_advanced",
          "~automation.home_settings",
          "~Home"
        ]);
        return {
          result:
            (screen === "home" && available.has(args.selector)) ||
            (screen !== "home" && args.selector === "~Home")
        };
      }
      if (command === "ui.tap") {
        if (options.throwOnSelector && args.selector === options.throwOnSelector) {
          throw new Error(
            `Can't call click on element with selector "${args.selector}" because element wasn't found`
          );
        }
        if (args.selector === "~automation.home_privacy_pulse") {
          screen = "privacyPulse";
        } else if (args.selector === "~automation.home_advanced") {
          screen = "advanced";
        } else if (args.selector === "~automation.home_settings") {
          screen = "settings";
        } else if (
          args.selector === "~automation.nav_back" ||
          args.selector === "~Home"
        ) {
          // The top-bar back button pops one level; in this flat fake model
          // every detail surface sits directly under Home.
          screen = "home";
        }
        return { result: "tapped" };
      }
      if (command === "ui.back") {
        if (backReturnsHome) {
          screen = "home";
        }
        return { result: "back" };
      }
      return { result: { ok: true } };
    },
    async shutdown() {
      commands.push({ command: "shutdown", args: {} });
    }
  };
}

test("runAiExplorer completes with fake model and fake client", async () => {
  const client = makeFakeClient();
  const outputDir = await mkdtemp(join(tmpdir(), "ai-explorer-runner-"));
  const report = await runAiExplorer({
    client,
    config: {
      advisory: true,
      apiKey: "",
      baseUrl: "http://localhost:1234/v1",
      fakeModel: true,
      maxTokens: 100,
      minSteps: 1,
      model: "fake",
      modelTimeoutMs: 1000,
      stepLimit: 8,
      temperature: 0,
      timeoutMs: 30000
    },
    env: {
      APP_BUNDLE_ID: "net.blocka.app",
      IOS_DEVICE_NAME: "Unit iPhone",
      IOS_UDID: "unit-udid"
    },
    outputDir
  });

  assert.equal(report.infrastructureFailure, false);
  assert.equal(report.completed, true);
  assert.equal(deriveReportStatus(report), "pass");
  assert.ok(client.commands.some((entry) => entry.command === "ui.scroll"));
  assert.deepEqual(
    report.mission
      .filter((entry) => ["privacyPulse", "advanced", "settings"].includes(entry.id))
      .map((entry) => [entry.id, entry.seen]),
    [
      ["privacyPulse", true],
      ["advanced", true],
      ["settings", true]
    ]
  );
  assert.equal(
    report.mission.find((entry) => entry.id === "activityRoute"),
    undefined
  );
  assert.match(report.artifacts.markdownPath, /ai-explorer-report\.md$/);
});

test("runAiExplorer returns Home via the back button when platform back is a no-op", async () => {
  const client = makeFakeClient({ backReturnsHome: false });
  const outputDir = await mkdtemp(join(tmpdir(), "ai-explorer-runner-"));
  const report = await runAiExplorer({
    client,
    config: {
      advisory: true,
      apiKey: "",
      baseUrl: "http://localhost:1234/v1",
      fakeModel: true,
      maxTokens: 100,
      minSteps: 1,
      model: "fake",
      modelTimeoutMs: 1000,
      stepLimit: 8,
      temperature: 0,
      timeoutMs: 30000
    },
    env: {
      APP_BUNDLE_ID: "net.blocka.app",
      IOS_DEVICE_NAME: "Unit iPhone",
      IOS_UDID: "unit-udid"
    },
    outputDir
  });

  assert.equal(deriveReportStatus(report), "pass");
  assert.ok(
    client.commands.some(
      (entry) =>
        entry.command === "ui.tap" && entry.args?.selector === "~automation.nav_back"
    )
  );
  assert.equal(report.mission.find((entry) => entry.id === "advanced")?.seen, true);
  assert.equal(report.mission.find((entry) => entry.id === "settings")?.seen, true);
});

test("a model selector that does not resolve is advisory, status stays pass", async () => {
  const client = makeFakeClient({ throwOnSelector: "~automation.bogus" });
  const outputDir = await mkdtemp(join(tmpdir(), "ai-explorer-runner-"));
  const decisions = [
    { command: "ui.tap", args: { selector: "~automation.bogus" }, reason: "probe", confidence: 1 },
    { command: "finish", args: {}, reason: "done", confidence: 1 }
  ];
  let index = 0;
  const report = await runAiExplorer({
    client,
    config: {
      advisory: true,
      apiKey: "",
      baseUrl: "http://localhost:1234/v1",
      fakeModel: false,
      maxTokens: 100,
      minSteps: 1,
      model: "fake",
      modelTimeoutMs: 1000,
      stepLimit: 6,
      temperature: 0,
      timeoutMs: 30000
    },
    decisionProvider: async () => decisions[Math.min(index++, decisions.length - 1)],
    env: {
      APP_BUNDLE_ID: "net.blocka.app",
      IOS_DEVICE_NAME: "Unit iPhone",
      IOS_UDID: "unit-udid"
    },
    outputDir
  });

  assert.equal(deriveReportStatus(report), "pass");
  const finding = report.findings.find((entry) =>
    entry.message.includes("~automation.bogus")
  );
  assert.ok(finding, "expected a finding for the unresolved selector");
  assert.equal(finding.severity, "info");
});

test("a titled screen with an empty body is critical and interrupts the run", async () => {
  // Chrome-only screen: a title (automation.screen_title) + back, no body —
  // the generic blank/broken-screen signature for any WithTopBar screen.
  const commands = [];
  const blankClient = {
    commands,
    start() {},
    async command(command) {
      commands.push(command);
      if (command === "session.status") {
        return { result: { deviceName: "Unit iPhone", udid: "unit-udid" } };
      }
      if (command === "ui.summary") {
        return {
          result: {
            appState: { code: 4, label: "running-foreground" },
            bundleId: "net.blocka.app",
            labels: ["automation.screen_title", "automation.nav_back", "back"],
            target: "six"
          }
        };
      }
      if (command === "ui.inspect") {
        return {
          result: {
            labels: ["automation.screen_title", "automation.nav_back"],
            elements: [
              { name: "automation.screen_title", label: "Advanced", visible: true },
              { name: "automation.nav_back", label: "back", visible: true }
            ],
            tree: []
          }
        };
      }
      if (command === "ui.exists") return { result: false };
      if (command === "ui.scroll") return { result: "down" };
      if (command === "ui.tap") return { result: "tapped" };
      if (command === "ui.back") return { result: "back" };
      if (command === "ui.wait") return { result: true };
      return { result: { ok: true } };
    },
    async shutdown() {}
  };
  const outputDir = await mkdtemp(join(tmpdir(), "ai-explorer-runner-"));
  const report = await runAiExplorer({
    client: blankClient,
    config: {
      advisory: true,
      apiKey: "",
      baseUrl: "http://localhost:1234/v1",
      fakeModel: true,
      maxTokens: 100,
      minSteps: 1,
      model: "fake",
      modelTimeoutMs: 1000,
      stepLimit: 12,
      temperature: 0,
      timeoutMs: 30000
    },
    env: {
      APP_BUNDLE_ID: "net.blocka.app",
      IOS_DEVICE_NAME: "Unit iPhone",
      IOS_UDID: "unit-udid"
    },
    outputDir
  });

  assert.equal(deriveReportStatus(report), "critical");
  assert.equal(report.completed, true);
  const blank = report.findings.find(
    (entry) =>
      entry.severity === "critical" && /blank\/broken screen/.test(entry.message)
  );
  assert.ok(blank, "expected a critical blank/broken-screen finding");
  // Interrupted: it must not have run the full model-step budget.
  assert.ok(
    report.steps.filter((s) => s.kind === "model").length < 12,
    "run should have been interrupted before exhausting the step budget"
  );
});

test("leaving the target app (unrecoverable) is critical and interrupts the run", async () => {
  // ui.summary keeps reporting a different foreground app (targetVerified
  // false) even after app.activate — a stuck wrong-app, e.g. a notification
  // banner tap that switched to Signal and recovery cannot get back.
  const offTargetClient = {
    start() {},
    async command(command) {
      if (command === "session.status") {
        return { result: { deviceName: "Unit iPhone", udid: "unit-udid" } };
      }
      if (command === "ui.summary") {
        return {
          result: {
            appState: { code: 4, label: "running-foreground" },
            activeApp: { bundleId: "org.whispersystems.signal", name: "Signal" },
            targetVerified: false,
            labels: ["Signal", "Chats", "New message"],
            target: "external"
          }
        };
      }
      if (command === "ui.inspect") {
        return { result: { labels: ["Signal", "Chats"], elements: [], tree: [] } };
      }
      if (command === "ui.exists") return { result: false };
      if (command === "ui.scroll") return { result: "down" };
      if (command === "ui.tap") return { result: "tapped" };
      if (command === "ui.back") return { result: "back" };
      if (command === "ui.wait") return { result: true };
      if (command === "app.activate") return { result: { ok: true } };
      return { result: { ok: true } };
    },
    async shutdown() {}
  };
  const outputDir = await mkdtemp(join(tmpdir(), "ai-explorer-runner-"));
  const report = await runAiExplorer({
    client: offTargetClient,
    config: {
      advisory: true,
      apiKey: "",
      baseUrl: "http://localhost:1234/v1",
      fakeModel: true,
      maxTokens: 100,
      minSteps: 1,
      model: "fake",
      modelTimeoutMs: 1000,
      stepLimit: 12,
      temperature: 0,
      timeoutMs: 30000
    },
    env: {
      APP_BUNDLE_ID: "net.blocka.app",
      IOS_DEVICE_NAME: "Unit iPhone",
      IOS_UDID: "unit-udid"
    },
    outputDir
  });

  assert.equal(deriveReportStatus(report), "critical");
  assert.equal(report.completed, true);
  const wrongApp = report.findings.find(
    (entry) =>
      entry.severity === "critical" && /left the target app/.test(entry.message)
  );
  assert.ok(wrongApp, "expected a critical left-the-target-app finding");
  assert.ok(
    report.steps.filter((s) => s.kind === "model").length < 12,
    "run should have been interrupted, not exhausted the budget"
  );
});
