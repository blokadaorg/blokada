import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  lostToInstrumentation,
  parseSpecResult,
  readSpecResults,
  specsToRetry
} from "../lib/instrumentation-retry.mjs";

const SETUP = "./src/specs/smoke/android-protection.spec.ts";
const LOST =
  "WebDriverError: &apos;POST /element&apos; cannot be proxied to UiAutomator2 server because the instrumentation process is not running (probably crashed).";

function junit(spec, cases) {
  const body = cases
    .map(([name, failure]) =>
      failure === undefined
        ? `<testcase classname="c" name="${name}" time="1"/>`
        : `<testcase classname="c" name="${name}" time="1"><failure message="${failure}"/></testcase>`
    )
    .join("");
  return (
    `<?xml version="1.0"?><testsuites><testsuite name="s"><properties>` +
    `<property name="file" value="file:///home/runner/work/x/automation/appium/wdio/src/specs/smoke/${spec}"/>` +
    `</properties>${body}</testsuite></testsuites>`
  );
}

test("parseSpecResult names the spec and collects failed cases", () => {
  const result = parseSpecResult(junit("tab-navigation.spec.ts", [["a"], ["b", LOST]]));
  assert.equal(result.spec, "./src/specs/smoke/tab-navigation.spec.ts");
  assert.equal(result.failures.length, 1);
  assert.ok(lostToInstrumentation(result));
});

test("an assertion failure is not an instrumentation loss", () => {
  const result = parseSpecResult(
    junit("power-pause.spec.ts", [["a", "AssertionError: expected &apos;inactive&apos; to equal &apos;active&apos;"]])
  );
  assert.equal(lostToInstrumentation(result), false);
});

test("a spec mixing a lost instrumentation with an assertion is not retried as lost", () => {
  const result = parseSpecResult(
    junit("power-pause.spec.ts", [["a", LOST], ["b", "AssertionError: expected 1 to equal 2"]])
  );
  assert.equal(lostToInstrumentation(result), false);
});

test("retries from the first lost spec onward, after the setup spec", () => {
  const results = [
    { spec: SETUP, failures: [] },
    { spec: "./tab.spec.ts", failures: [LOST] },
    { spec: "./settings.spec.ts", failures: [] },
    { spec: "./power.spec.ts", failures: ["AssertionError: protection should be active"] }
  ];
  assert.deepEqual(specsToRetry(results, SETUP), [SETUP, "./tab.spec.ts", "./power.spec.ts"]);
});

test("does not retry when the first failure is an app failure", () => {
  const results = [
    { spec: SETUP, failures: ["AssertionError: protection should start off"] },
    { spec: "./tab.spec.ts", failures: [LOST] }
  ];
  assert.deepEqual(specsToRetry(results, SETUP), []);
});

test("does not retry a green run", () => {
  assert.deepEqual(specsToRetry([{ spec: SETUP, failures: [] }], SETUP), []);
});

test("readSpecResults keeps run order and the attempt prefix", () => {
  const dir = mkdtempSync(join(tmpdir(), "junit-"));
  writeFileSync(join(dir, "results-1-0-10.xml"), junit("power-pause.spec.ts", [["a"]]));
  writeFileSync(join(dir, "results-1-0-2.xml"), junit("tab-navigation.spec.ts", [["a", LOST]]));
  writeFileSync(join(dir, "results-2-0-0.xml"), junit("android-protection.spec.ts", [["a"]]));
  const results = readSpecResults(dir, "results-1-");
  assert.deepEqual(
    results.map((r) => [r.file, r.spec]),
    [
      ["results-1-0-2.xml", "./src/specs/smoke/tab-navigation.spec.ts"],
      ["results-1-0-10.xml", "./src/specs/smoke/power-pause.spec.ts"]
    ]
  );
});
