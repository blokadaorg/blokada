import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

export function createExplorerReport({ config, deviceName, startedAt, udid }) {
  return {
    completed: false,
    config,
    deviceName,
    durationMs: 0,
    findings: [],
    infrastructureFailure: false,
    startedAt,
    steps: [],
    summary: "",
    udid
  };
}

function stableDetailsKey(value) {
  if (value == null || typeof value !== "object") {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map((item) => stableDetailsKey(item)).join(",")}]`;
  }
  return `{${Object.keys(value)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${stableDetailsKey(value[key])}`)
    .join(",")}}`;
}

export function addFinding(report, severity, message, details = {}, options = {}) {
  const dedupeKey =
    options.dedupeKey ?? `${severity}:${message}:${stableDetailsKey(details)}`;
  if (report.findings.some((finding) => finding.dedupeKey === dedupeKey)) {
    return;
  }

  report.findings.push({
    dedupeKey,
    details,
    message,
    severity,
    timestamp: new Date().toISOString()
  });
}

export function addStep(report, step) {
  report.steps.push({
    timestamp: new Date().toISOString(),
    ...step
  });
}

export function deriveReportStatus(report) {
  if (report.infrastructureFailure) {
    return "infrastructure-failure";
  }
  if (report.findings.some((finding) => finding.severity === "critical")) {
    return "critical";
  }
  if (report.findings.some((finding) => finding.severity === "warning")) {
    return "warning";
  }
  return report.completed ? "pass" : "incomplete";
}

function formatJsonBlock(value) {
  return `\n\`\`\`json\n${JSON.stringify(value, null, 2)}\n\`\`\`\n`;
}

export function renderMarkdownReport(report) {
  const status = deriveReportStatus(report);
  const lines = [
    "# Appium AI Explorer Report",
    "",
    `- Status: ${status}`,
    `- Completed: ${report.completed ? "yes" : "no"}`,
    `- Duration: ${Math.round(report.durationMs / 1000)}s`,
    `- Device: ${report.deviceName ?? "unknown"}`,
    `- Model: ${report.config.model}`,
    `- Endpoint: ${report.config.baseUrl}`,
    `- Advisory: ${report.config.advisory ? "yes" : "no"}`,
    "",
    "## Findings",
    ""
  ];

  if (report.findings.length === 0) {
    lines.push("No findings recorded.", "");
  } else {
    for (const finding of report.findings) {
      lines.push(`- ${finding.severity}: ${finding.message}`);
    }
    lines.push("");
  }

  const recentSteps = report.steps.slice(-20);
  lines.push("## Recent Steps", "");
  if (recentSteps.length === 0) {
    lines.push("No steps recorded.", "");
  } else {
    for (const step of recentSteps) {
      const suffix = step.reason ? ` - ${step.reason}` : "";
      lines.push(`- ${step.kind ?? "step"}: ${step.command ?? step.event ?? ""}${suffix}`);
    }
    lines.push("");
  }

  if (report.summary) {
    lines.push("## Summary", "", report.summary, "");
  }

  if (Array.isArray(report.mission) && report.mission.length > 0) {
    lines.push("## Mission Coverage", "");
    for (const surface of report.mission) {
      const status = surface.seen ? "seen" : surface.attempted ? "attempted" : "not reached";
      lines.push(`- ${surface.name}: ${status}`);
    }
    lines.push("");
  }

  if (report.findings.some((finding) => Object.keys(finding.details ?? {}).length > 0)) {
    lines.push("## Details", "");
    lines.push(formatJsonBlock(report.findings.map(({ dedupeKey, ...finding }) => finding)));
  }

  return lines.join("\n");
}

export async function writeExplorerReports(report, outputDir) {
  await mkdir(outputDir, { recursive: true });
  const jsonPath = resolve(outputDir, "ai-explorer-report.json");
  const markdownPath = resolve(outputDir, "ai-explorer-report.md");
  const publicReport = {
    ...report,
    findings: report.findings.map(({ dedupeKey, ...finding }) => finding)
  };
  await writeFile(jsonPath, JSON.stringify(publicReport, null, 2), "utf8");
  await writeFile(markdownPath, renderMarkdownReport(publicReport), "utf8");
  return {
    jsonPath,
    markdownPath
  };
}
