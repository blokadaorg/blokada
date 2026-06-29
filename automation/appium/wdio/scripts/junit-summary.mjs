#!/usr/bin/env node

// Render a per-scenario Markdown table from the JUnit XML the wdio junit reporter
// writes to automation/appium/output/junit. Intended for the CI run summary:
//   node scripts/junit-summary.mjs >> "$GITHUB_STEP_SUMMARY"
// Always exits 0 (the CI gate decides pass/fail from step outcomes, not this).

import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const defaultJunitDir = resolve(scriptDir, "..", "..", "output", "junit");

const ENTITIES = {
  "&amp;": "&",
  "&lt;": "<",
  "&gt;": ">",
  "&quot;": '"',
  "&apos;": "'",
  "&#39;": "'"
};

function unescapeXml(value) {
  return value.replace(/&(amp|lt|gt|quot|apos|#39);/g, (m) => ENTITIES[m] ?? m);
}

function attr(attrs, name) {
  // \b so `name` does not match inside `classname`.
  const match = attrs.match(new RegExp(`\\b${name}="([^"]*)"`));
  return match ? unescapeXml(match[1]) : "";
}

function formatDuration(seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) return "—";
  if (seconds < 60) return `${seconds.toFixed(1)}s`;
  const mins = Math.floor(seconds / 60);
  const secs = Math.round(seconds % 60);
  return `${mins}m ${secs}s`;
}

/** Parse one JUnit XML string into rows of {suite, name, status, time}. */
export function parseTestcases(xml) {
  const rows = [];
  const suiteRe = /<testsuite\b([^>]*)>([\s\S]*?)<\/testsuite>/g;
  let suiteMatch;
  while ((suiteMatch = suiteRe.exec(xml)) !== null) {
    const suite = attr(suiteMatch[1], "name");
    const body = suiteMatch[2];
    const caseRe = /<testcase\b([^>]*?)(\/>|>([\s\S]*?)<\/testcase>)/g;
    let caseMatch;
    while ((caseMatch = caseRe.exec(body)) !== null) {
      const caseAttrs = caseMatch[1];
      const caseBody = caseMatch[3] ?? "";
      let status = "passed";
      if (/<failure\b/.test(caseBody)) status = "failed";
      else if (/<error\b/.test(caseBody)) status = "error";
      else if (/<skipped\b/.test(caseBody)) status = "skipped";
      rows.push({
        suite: suite || attr(caseAttrs, "classname"),
        name: attr(caseAttrs, "name"),
        status,
        time: Number.parseFloat(attr(caseAttrs, "time")) || 0
      });
    }
  }
  return rows;
}

const ICON = { passed: "✅", failed: "❌", error: "❌", skipped: "⏭️" };

/** Build the Markdown summary from already-parsed rows. */
export function buildMarkdown(rows) {
  if (rows.length === 0) {
    return "## Appium smoke — scenario results\n\n_No JUnit results found._\n";
  }
  const lines = [
    "## Appium smoke — scenario results",
    "",
    "| | Scenario | Test | Duration |",
    "| :-: | --- | --- | --- |"
  ];
  for (const r of rows) {
    lines.push(
      `| ${ICON[r.status] ?? "❔"} | ${r.suite || "—"} | ${r.name || "—"} | ${formatDuration(r.time)} |`
    );
  }
  const passed = rows.filter((r) => r.status === "passed").length;
  const failed = rows.filter((r) => r.status === "failed" || r.status === "error").length;
  const skipped = rows.filter((r) => r.status === "skipped").length;
  const total = rows.reduce((sum, r) => sum + r.time, 0);
  const noun = rows.length === 1 ? "scenario" : "scenarios";
  const parts = [`**${rows.length} ${noun}** — ${passed} passed`];
  if (failed) parts.push(`${failed} failed`);
  if (skipped) parts.push(`${skipped} skipped`);
  lines.push("", `${parts.join(", ")} · total ${formatDuration(total)}`);
  return `${lines.join("\n")}\n`;
}

function readJunitRows(junitDir) {
  let files;
  try {
    files = readdirSync(junitDir)
      .filter((f) => f.startsWith("results-") && f.endsWith(".xml"))
      .map((f) => resolve(junitDir, f))
      .sort((a, b) => statSync(a).mtimeMs - statSync(b).mtimeMs);
  } catch {
    return [];
  }
  return files.flatMap((file) => {
    try {
      return parseTestcases(readFileSync(file, "utf8"));
    } catch {
      return []; // skip an unreadable/disappeared file rather than fail the job
    }
  });
}

function main() {
  const junitDir = process.env.JUNIT_DIR
    ? resolve(process.env.JUNIT_DIR)
    : defaultJunitDir;
  process.stdout.write(buildMarkdown(readJunitRows(junitDir)));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
