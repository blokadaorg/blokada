import test from "node:test";
import assert from "node:assert/strict";

import { evaluateExplorerAction } from "../lib/ai-explorer-guardrails.mjs";

test("guardrails allow safe app inspection commands", () => {
  const result = evaluateExplorerAction(
    {
      command: "ui.inspect",
      args: { limit: 500, source: true },
      reason: "Inspect visible controls."
    },
    { sessionBundleId: "net.blocka.app" }
  );

  assert.equal(result.allowed, true);
  assert.equal(result.action.args.limit, 60);
  assert.equal(result.action.args.visibleOnly, true);
  assert.equal(result.action.args.source, undefined);
});

test("guardrails deny risky purchase and account actions", () => {
  const result = evaluateExplorerAction(
    {
      command: "ui.tap",
      args: { selector: "~Start trial" },
      reason: "Check the trial purchase flow."
    },
    { sessionBundleId: "net.blocka.app" }
  );

  assert.equal(result.allowed, false);
  assert.match(result.reason, /risky/);
});

test("guardrails deny unsupported commands", () => {
  const result = evaluateExplorerAction(
    {
      command: "ui.type",
      args: { selector: "~Email", text: "test@example.com" },
      reason: "Type into a field."
    },
    { sessionBundleId: "net.blocka.app" }
  );

  assert.equal(result.allowed, false);
  assert.match(result.reason, /allowlist/);
});

test("guardrails deny invented selector strings", () => {
  const result = evaluateExplorerAction(
    {
      command: "ui.tap",
      args: { selector: "XCUIElementTypeSwitch value=\"0\"" },
      reason: "Tap a switch."
    },
    { sessionBundleId: "net.blocka.app" }
  );

  assert.equal(result.allowed, false);
  assert.match(result.reason, /selector must/);
});

test("guardrails keep app activation inside the configured app", () => {
  const allowed = evaluateExplorerAction(
    {
      command: "app.activate",
      args: {},
      reason: "Return to app."
    },
    { sessionBundleId: "net.blocka.app" }
  );
  const denied = evaluateExplorerAction(
    {
      command: "app.activate",
      args: { bundleId: "com.apple.Preferences" },
      reason: "Open Settings."
    },
    { sessionBundleId: "net.blocka.app" }
  );

  assert.equal(allowed.allowed, true);
  assert.equal(denied.allowed, false);
});
