import test from "node:test";
import assert from "node:assert/strict";

import { parseSuites, buildMarkdown } from "../junit-summary.mjs";

// Mirrors the real wdio junit output: testsuite time (wall-clock incl. hooks +
// WDA startup) is much larger than the testcase time (it() body), and the nice
// suite name lives in the suiteName property (the name attr is sanitized).
const PASS_XML = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="Smoke Home hub navigation" time="129.792" tests="1" failures="0">
    <properties><property name="suiteName" value="Smoke: Home hub navigation"/></properties>
    <testcase classname="home" name="opens each main screen from Home and returns" time="10.013"/>
  </testsuite>
</testsuites>`;

const FAIL_XML = `<?xml version="1.0"?>
<testsuites>
  <testsuite name="Smoke power pause turn off" time="126.879" tests="1" failures="1">
    <properties><property name="suiteName" value="Smoke: power pause / turn-off"/></properties>
    <testcase classname="power" name="turns protection off" time="7.176">
      <failure message="boom">stack</failure>
    </testcase>
  </testsuite>
</testsuites>`;

test("parseSuites uses suite wall-clock as duration and the property suite name", () => {
  const suites = parseSuites(PASS_XML);
  assert.equal(suites.length, 1);
  assert.deepEqual(suites[0], {
    suite: "Smoke: Home hub navigation",
    status: "passed",
    duration: 129.792,
    testTime: 10.013
  });
});

test("parseSuites detects failures", () => {
  const suites = parseSuites(FAIL_XML);
  assert.equal(suites.length, 1);
  assert.equal(suites[0].status, "failed");
  assert.equal(suites[0].suite, "Smoke: power pause / turn-off");
  assert.equal(suites[0].duration, 126.879);
});

test("buildMarkdown shows duration + test exec and totals by suite time", () => {
  const md = buildMarkdown([...parseSuites(PASS_XML), ...parseSuites(FAIL_XML)]);
  assert.match(md, /Appium smoke — scenario results/);
  assert.match(md, /Duration \| Test exec/);
  assert.match(md, /2m 10s/); // 129.792 suite time
  assert.match(md, /10\.0s/); // 10.013 test exec
  assert.match(md, /\*\*2 scenarios\*\* — 1 passed, 1 failed/);
  assert.match(md, /total 4m 17s/); // 129.792 + 126.879 = 256.671s
});

test("buildMarkdown handles no results", () => {
  assert.match(buildMarkdown([]), /No JUnit results found/);
});
