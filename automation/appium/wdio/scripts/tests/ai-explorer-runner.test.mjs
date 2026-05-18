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
        if (args.selector === "~automation.home_privacy_pulse") {
          screen = "privacyPulse";
        } else if (args.selector === "~automation.home_advanced") {
          screen = "advanced";
        } else if (args.selector === "~automation.home_settings") {
          screen = "settings";
        } else if (args.selector === "~Home") {
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
      .map((entry) => [entry.id, entry.seen, entry.attempted]),
    [
      ["privacyPulse", true, true],
      ["advanced", true, true],
      ["settings", true, true]
    ]
  );
  assert.equal(
    report.mission.find((entry) => entry.id === "activityRoute"),
    undefined
  );
  assert.match(report.artifacts.markdownPath, /ai-explorer-report\.md$/);
});

test("runAiExplorer taps Home when back does not leave a detail surface", async () => {
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
      (entry) => entry.command === "ui.tap" && entry.args?.selector === "~Home"
    )
  );
  assert.equal(report.mission.find((entry) => entry.id === "advanced")?.seen, true);
  assert.equal(report.mission.find((entry) => entry.id === "settings")?.seen, true);
});
