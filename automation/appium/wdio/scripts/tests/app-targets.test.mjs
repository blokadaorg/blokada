import test from "node:test";
import assert from "node:assert/strict";

import {
  buildKnownAppTargets,
  resolveAppDisplayName,
  resolveAppFlavor,
  resolveInstallTarget,
  resolvePrimaryBundleId
} from "../lib/app-targets.mjs";

test("resolveAppFlavor defaults to six", () => {
  assert.equal(resolveAppFlavor({}), "six");
  assert.equal(resolvePrimaryBundleId({}), "net.blocka.app");
  assert.equal(resolveInstallTarget({}), "appium-install-six");
  assert.equal(resolveAppDisplayName({}), "Blokada 6");
});

test("resolveAppFlavor supports family through APP_FLAVOR", () => {
  const env = { APP_FLAVOR: "family" };

  assert.equal(resolveAppFlavor(env), "family");
  assert.equal(resolvePrimaryBundleId(env), "net.blocka.app.family");
  assert.equal(resolveInstallTarget(env), "appium-install-family");
  assert.equal(resolveAppDisplayName(env), "Blokada Family");
});

test("resolveAppFlavor infers family from bundle id", () => {
  const env = { APP_BUNDLE_ID: "net.blocka.app.family" };

  assert.equal(resolveAppFlavor(env), "family");
  assert.equal(resolvePrimaryBundleId(env), "net.blocka.app.family");
});

test("resolveAppFlavor rejects unsupported explicit flavor values", () => {
  assert.throws(
    () => resolveAppFlavor({ APP_FLAVOR: "famliy" }),
    /Unsupported APP_FLAVOR='famliy'/
  );
  assert.throws(
    () => resolveInstallTarget({ APP_FLAVOR: "famliy" }),
    /Unsupported APP_FLAVOR='famliy'/
  );
});

test("buildKnownAppTargets exposes only concrete app targets", () => {
  assert.deepEqual(
    buildKnownAppTargets().map((target) => target.name),
    ["six", "family", "settings"]
  );
});
