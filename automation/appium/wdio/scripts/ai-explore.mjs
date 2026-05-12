#!/usr/bin/env node

import process from "node:process";

import { runAiExplorer } from "./lib/ai-explorer-runner.mjs";
import { deriveReportStatus } from "./lib/ai-explorer-report.mjs";

const report = await runAiExplorer();
const status = deriveReportStatus(report);

process.stderr.write(
  `AI explorer status: ${status}. Report: ${report.artifacts?.markdownPath ?? "unavailable"}\n`
);

if (report.infrastructureFailure) {
  process.exit(1);
}

if (!report.config.advisory && status === "critical") {
  process.exit(1);
}
