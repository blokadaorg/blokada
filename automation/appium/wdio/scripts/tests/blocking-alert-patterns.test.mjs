import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// alerts.ts is TypeScript and imports @wdio/globals (needs a live session), so
// it cannot be imported here. Instead the patterns are read out of the source,
// which keeps this test honest: it asserts against the committed regexes rather
// than a copy that can silently drift.
const alertsSource = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
  "src",
  "flows",
  "alerts.ts"
);

function loadBlockingPatterns() {
  const source = readFileSync(alertsSource, "utf8");
  const block = source.match(/const blockingSystemAlertPatterns = \[([\s\S]*?)\];/);
  assert.ok(block, "blockingSystemAlertPatterns array not found in alerts.ts");
  const patterns = [...block[1].matchAll(/\/(.+?)\/([gimsuy]*)/g)].map(
    (match) => new RegExp(match[1], match[2])
  );
  assert.ok(patterns.length > 0, "no regex literals parsed out of the array");
  return patterns;
}

const blocks = (text) => loadBlockingPatterns().some((pattern) => pattern.test(text));

// Device-level modals: only a human at the device can clear them, and they
// swallow every tap while the app stays visible in the accessibility tree.
test("blocking patterns catch device modals that need a human", () => {
  // Verbatim from the four consecutive red appium-smoke runs on 2026-07-20,
  // where this alert made all 11 specs fail on an unrelated selector.
  assert.equal(
    blocks(
      "Apple Account Sign In Requested\n" +
        "Your Apple Account is being used to sign in on the web."
    ),
    true
  );
  assert.equal(blocks("Apple ID Sign In Requested"), true);
  assert.equal(blocks("Software Update Available"), true);
  assert.equal(blocks("Trust This Computer?"), true);
  assert.equal(blocks("iPhone Storage is Almost Full"), true);
});

// The expensive failure mode: tripping on an alert a spec legitimately raises
// would fail a run that should pass. Guard the known flow alerts explicitly —
// especially Apple-ID sign-in, which the StoreKit sandbox purchase sheet shows
// mid-flow (dep-validate Stage D drives purchase/restore).
test("blocking patterns ignore alerts that flows legitimately raise", () => {
  assert.equal(blocks('"Blokada" Would Like to Add VPN Configurations'), false);
  assert.equal(blocks('"Blokada" would like to add DNS configurations'), false);
  assert.equal(blocks('"Blokada" Would Like to Send You Notifications'), false);
  assert.equal(blocks("Sign In to iTunes Store"), false);
  assert.equal(blocks("Enter the password for your Apple ID"), false);
  assert.equal(blocks("Apple Account"), false);
  assert.equal(blocks("Confirm Your In-App Purchase"), false);
});
