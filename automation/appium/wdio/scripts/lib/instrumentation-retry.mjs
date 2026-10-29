// Decides whether an Android smoke run lost spec files to the emulator rather
// than to the app, from the JUnit XML the wdio junit reporter writes.
//
// On the hosted emulator, adb sometimes drops the device for a few seconds.
// UiAutomator2 runs its server through `adb shell am instrument`, so the drop
// kills it, and every command after that fails with "instrumentation process is
// not running". Those spec files are re-run once; app assertion failures never
// are.

import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

// Failures that mean the device link died, not the app.
export const INSTRUMENTATION_LOST =
  /instrumentation process is not running|instrumentation process cannot be initialized|Could not proxy command to the remote server|adb: device offline|device '[^']*' not found|exited with code 255/;

const ENTITIES = { "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"', "&apos;": "'", "&#39;": "'" };

function unescapeXml(value) {
  return value.replace(/&(amp|lt|gt|quot|apos|#39);/g, (m) => ENTITIES[m] ?? m);
}

/**
 * One JUnit file → { spec, failures: [text of each failed testcase] }, or
 * undefined when the file names no spec.
 */
export function parseSpecResult(xml) {
  const spec = xml.match(/src\/specs\/[^"<>]+?\.spec\.ts/)?.[0];
  if (!spec) return undefined;
  const failures = [];
  const caseRe = /<testcase\b[^>]*?(?:\/>|>([\s\S]*?)<\/testcase>)/g;
  let match;
  while ((match = caseRe.exec(xml)) !== null) {
    const body = match[1] ?? "";
    if (/<failure\b|<error\b/.test(body)) failures.push(unescapeXml(body));
  }
  return { spec: `./${spec}`, failures };
}

/** Results of one attempt, in run order (wdio numbers workers 0-0, 0-1, ...). */
export function readSpecResults(junitDir, prefix) {
  const order = (name) => Number(name.match(/-(\d+)\.xml$/)?.[1] ?? Number.MAX_SAFE_INTEGER);
  return readdirSync(junitDir)
    .filter((name) => name.startsWith(prefix) && name.endsWith(".xml"))
    .sort((a, b) => order(a) - order(b))
    .map((name) => ({ file: name, ...parseSpecResult(readFileSync(join(junitDir, name), "utf8")) }))
    .filter((result) => result.spec);
}

export function lostToInstrumentation(result) {
  return result.failures.length > 0 && result.failures.every((f) => INSTRUMENTATION_LOST.test(f));
}

/**
 * Spec files to run again, or [] for none. Retries only when the first spec
 * that failed lost its instrumentation: later failures can be fallout from it
 * (protection never turned on), so they run again too, after `setupSpec`,
 * which puts the device back in the state the others expect. If the first
 * failure is anything else, nothing is retried.
 */
export function specsToRetry(results, setupSpec) {
  const failed = results.filter((r) => r.failures.length > 0);
  if (failed.length === 0 || !lostToInstrumentation(failed[0])) return [];
  return [...new Set([setupSpec, ...failed.map((r) => r.spec)])];
}
