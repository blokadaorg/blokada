#!/usr/bin/env node

// Render a per-scenario Markdown table from the JUnit XML the wdio junit reporter
// writes to automation/appium/output/junit. Intended for the CI run summary:
//   node scripts/junit-summary.mjs >> "$GITHUB_STEP_SUMMARY"
// Always exits 0 (the smoke step is the gate; this is reporting only).
//
// Per-scenario "Duration" is the JUnit <testsuite time> — the scenario's
// wall-clock including before/after hooks (app relaunch + account restore) and
// the per-spec WebDriverAgent session startup. "Test exec" is the <testcase
// time> (the it() body alone), which is much smaller. Neither includes the
// one-time npm install + app build/install that runs once before all scenarios,
// so the total here is below the full CI step time.

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

/**
 * Parse one JUnit XML string into per-suite rows:
 *   { suite, status, duration (suite wall-clock), testTime (sum of it() bodies) }
 */
export function parseSuites(xml) {
  const suites = [];
  const suiteRe = /<testsuite\b([^>]*)>([\s\S]*?)<\/testsuite>/g;
  let suiteMatch;
  while ((suiteMatch = suiteRe.exec(xml)) !== null) {
    const suiteAttrs = suiteMatch[1];
    const body = suiteMatch[2];
    // Prefer the unsanitized suiteName property; the testsuite name attr has
    // ':' and '/' stripped by the reporter.
    const prop = body.match(/<property\b[^>]*\bname="suiteName"[^>]*\bvalue="([^"]*)"/);
    const suite = prop ? unescapeXml(prop[1]) : attr(suiteAttrs, "name");
    const duration = Number.parseFloat(attr(suiteAttrs, "time")) || 0;

    let testTime = 0;
    let total = 0;
    let failed = 0;
    let skipped = 0;
    const caseRe = /<testcase\b([^>]*?)(\/>|>([\s\S]*?)<\/testcase>)/g;
    let caseMatch;
    while ((caseMatch = caseRe.exec(body)) !== null) {
      total += 1;
      testTime += Number.parseFloat(attr(caseMatch[1], "time")) || 0;
      const caseBody = caseMatch[3] ?? "";
      if (/<failure\b/.test(caseBody) || /<error\b/.test(caseBody)) failed += 1;
      else if (/<skipped\b/.test(caseBody)) skipped += 1;
    }

    let status = "passed";
    if (failed > 0) status = "failed";
    else if (total === 0 || skipped === total) status = "skipped";
    suites.push({ suite, status, duration, testTime });
  }
  return suites;
}

const ICON = { passed: "✅", failed: "❌", skipped: "⏭️" };

/** Build the Markdown summary from already-parsed suite rows. */
export function buildMarkdown(suites) {
  if (suites.length === 0) {
    return "## Appium smoke — scenario results\n\n_No JUnit results found._\n";
  }
  const lines = [
    "## Appium smoke — scenario results",
    "",
    "| | Scenario | Duration | Test exec |",
    "| :-: | --- | --: | --: |"
  ];
  for (const s of suites) {
    lines.push(
      `| ${ICON[s.status] ?? "❔"} | ${s.suite || "—"} | ${formatDuration(s.duration)} | ${formatDuration(s.testTime)} |`
    );
  }
  const passed = suites.filter((s) => s.status === "passed").length;
  const failed = suites.filter((s) => s.status === "failed").length;
  const skipped = suites.filter((s) => s.status === "skipped").length;
  const total = suites.reduce((sum, s) => sum + s.duration, 0);
  const noun = suites.length === 1 ? "scenario" : "scenarios";
  const parts = [`**${suites.length} ${noun}** — ${passed} passed`];
  if (failed) parts.push(`${failed} failed`);
  if (skipped) parts.push(`${skipped} skipped`);
  lines.push("", `${parts.join(", ")} · total ${formatDuration(total)}`);
  lines.push(
    "",
    "_Duration is per-scenario wall-clock (app relaunch, account restore, " +
      "WebDriverAgent startup, hooks); Test exec is the test body alone. The " +
      "one-time npm + app build/install runs once before all scenarios and is " +
      "not attributed here, so the total is below the full step time._"
  );
  return `${lines.join("\n")}\n`;
}

function readSuites(junitDir) {
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
      return parseSuites(readFileSync(file, "utf8"));
    } catch {
      return []; // skip an unreadable/disappeared file rather than fail the job
    }
  });
}

function main() {
  const junitDir = process.env.JUNIT_DIR
    ? resolve(process.env.JUNIT_DIR)
    : defaultJunitDir;
  process.stdout.write(buildMarkdown(readSuites(junitDir)));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
