import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import {
  addFinding,
  addStep,
  createExplorerReport,
  deriveReportStatus,
  renderMarkdownReport,
  writeExplorerReports
} from "../lib/ai-explorer-report.mjs";

test("deriveReportStatus reports warning findings", () => {
  const report = createExplorerReport({
    config: { advisory: true, baseUrl: "http://localhost/v1", model: "model" },
    startedAt: "2026-01-01T00:00:00.000Z"
  });
  report.completed = true;
  addFinding(report, "warning", "Suspicious screen");

  assert.equal(deriveReportStatus(report), "warning");
  assert.match(renderMarkdownReport(report), /warning: Suspicious screen/);
});

test("addFinding keeps distinct details for repeated finding messages", () => {
  const report = createExplorerReport({
    config: { advisory: true, baseUrl: "http://localhost/v1", model: "model" },
    startedAt: "2026-01-01T00:00:00.000Z"
  });

  addFinding(report, "warning", "Explorer command failed", { selector: "~A" });
  addFinding(report, "warning", "Explorer command failed", { selector: "~B" });
  addFinding(report, "warning", "Explorer command failed", { selector: "~A" });

  assert.equal(report.findings.length, 2);
});

test("writeExplorerReports writes JSON and Markdown artifacts", async () => {
  const outputDir = await mkdtemp(join(tmpdir(), "ai-explorer-report-"));
  const report = createExplorerReport({
    config: { advisory: true, baseUrl: "http://localhost/v1", model: "model" },
    startedAt: "2026-01-01T00:00:00.000Z"
  });
  report.completed = true;
  addStep(report, { kind: "command", command: "ui.summary" });

  const artifacts = await writeExplorerReports(report, outputDir);

  assert.match(await readFile(artifacts.markdownPath, "utf8"), /Appium AI Explorer Report/);
  assert.equal(JSON.parse(await readFile(artifacts.jsonPath, "utf8")).completed, true);
});
