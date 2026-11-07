import test from "node:test";
import assert from "node:assert/strict";

import { gateReviewCommand } from "../review-session.mjs";

const SIX = "net.blocka.app";

test("review gate passes the explorer's safe commands through its guardrails", () => {
  const gated = gateReviewCommand("ui.inspect", { limit: 500 }, SIX);
  assert.equal(gated.command, "ui.inspect");
  assert.equal(gated.args.limit, 60);
});

test("review gate refuses commands outside both allowlists", () => {
  assert.match(gateReviewCommand("app.terminate", {}, SIX).error, /allowlist/);
  assert.match(gateReviewCommand("ui.source", {}, SIX).error, /allowlist/);
  assert.match(gateReviewCommand("finish", {}, SIX).error, /stop/);
});

test("review gate allows typing short text into a field", () => {
  const gated = gateReviewCommand("ui.type", { selector: "~Domain", text: "example.com" }, SIX);
  assert.deepEqual(gated, { command: "ui.type", args: { selector: "~Domain", text: "example.com" } });
});

test("review gate refuses risky or long text and bad selectors", () => {
  assert.match(gateReviewCommand("ui.type", { selector: "~Chat", text: "cancel subscription" }, SIX).error, /risky/);
  assert.match(gateReviewCommand("ui.type", { selector: "~Chat", text: "x".repeat(121) }, SIX).error, /120/);
  assert.match(gateReviewCommand("ui.type", { selector: "Chat", text: "hi" }, SIX).error, /selector/);
  assert.match(gateReviewCommand("ui.tapCenter", { selector: "~Start trial" }, SIX).error, /risky/);
});

test("review gate allows system alerts but not risky buttons", () => {
  assert.deepEqual(gateReviewCommand("ui.alert", { action: "accept", buttonLabel: "Allow" }, SIX), {
    command: "ui.alert",
    args: { action: "accept", buttonLabel: "Allow" }
  });
  assert.match(gateReviewCommand("ui.alert", { action: "tap" }, SIX).error, /accept/);
  assert.match(gateReviewCommand("ui.alert", { action: "accept" }, SIX).error, /buttonLabel/);
  assert.deepEqual(gateReviewCommand("ui.alert", { action: "getButtons" }, SIX), {
    command: "ui.alert",
    args: { action: "getButtons" }
  });
  assert.match(gateReviewCommand("ui.alert", { action: "accept", buttonLabel: "Delete" }, SIX).error, /risky/);
});

test("review screenshots get the review- prefix and a safe name", () => {
  assert.deepEqual(gateReviewCommand("ui.screenshot", { name: "../499 safe search" }, SIX), {
    command: "ui.screenshot",
    args: { name: "review-499-safe-search" }
  });
  assert.equal(gateReviewCommand("ui.screenshot", { name: "review-x" }, SIX).args.name, "review-x");
});

test("review gate keeps app.activate inside the current app", () => {
  assert.match(gateReviewCommand("app.activate", { bundleId: "com.apple.Preferences" }, SIX).error, /outside/);
});
