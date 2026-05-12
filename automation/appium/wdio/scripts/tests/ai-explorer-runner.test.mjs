import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { runAiExplorer } from "../lib/ai-explorer-runner.mjs";
import { deriveReportStatus } from "../lib/ai-explorer-report.mjs";

function makeFakeClient() {
  const commands = [];
  let scrollPosition = 0;
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
        return {
          result: {
            appState: { code: 4, label: "running-foreground" },
            bundleId: "net.blocka.app",
            labels: ["Privacy Pulse", "Settings", "Activity", `Scroll ${scrollPosition}`],
            target: "six"
          }
        };
      }
      if (command === "ui.inspect") {
        return {
          result: {
            elements: [
              {
                label: "Settings",
                name: "Settings",
                type: "XCUIElementTypeButton",
                visible: true
              }
            ],
            labels: ["Settings"],
            tree: ["XCUIElementTypeButton name=\"Settings\" label=\"Settings\""]
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
  assert.match(report.artifacts.markdownPath, /ai-explorer-report\.md$/);
});
