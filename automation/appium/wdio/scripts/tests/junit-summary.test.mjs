import test from "node:test";
import assert from "node:assert/strict";

import { parseTestcases, buildMarkdown } from "../junit-summary.mjs";

const PASS_XML = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="Smoke: Home hub navigation" tests="1" failures="0" time="41.2">
    <testcase classname="home" name="opens each main screen from Home and returns" time="41.2"/>
  </testsuite>
</testsuites>`;

const FAIL_XML = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="Smoke: power pause / turn-off" tests="1" failures="1" time="112">
    <testcase classname="power" name="turns protection off" time="112">
      <failure message="boom">stack</failure>
    </testcase>
  </testsuite>
</testsuites>`;

test("parseTestcases reads a passing testcase", () => {
  const rows = parseTestcases(PASS_XML);
  assert.equal(rows.length, 1);
  assert.deepEqual(rows[0], {
    suite: "Smoke: Home hub navigation",
    name: "opens each main screen from Home and returns",
    status: "passed",
    time: 41.2
  });
});

test("parseTestcases detects failures", () => {
  const rows = parseTestcases(FAIL_XML);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].status, "failed");
  assert.equal(rows[0].suite, "Smoke: power pause / turn-off");
});

test("buildMarkdown summarizes mixed results", () => {
  const md = buildMarkdown([...parseTestcases(PASS_XML), ...parseTestcases(FAIL_XML)]);
  assert.match(md, /Appium smoke — scenario results/);
  assert.match(md, /✅/);
  assert.match(md, /❌/);
  assert.match(md, /\*\*2 scenarios\*\* — 1 passed, 1 failed/);
});

test("buildMarkdown handles no results", () => {
  assert.match(buildMarkdown([]), /No JUnit results found/);
});
