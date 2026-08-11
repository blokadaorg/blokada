#!/usr/bin/env node
//
// Verifies that the bundled Adapty fallback paywalls JSON files use a format
// version recent enough for the shipped Adapty SDK. Older JSONs are rejected
// by the SDK at cold start with error 2006 ("Decoding Fallback Paywalls
// failed... The fallback paywalls version is not correct."), which silently
// degrades to StageModal.paymentTempUnavailable because the Dart catch in
// common/lib/src/features/payment/domain/adapty.dart swallows it.
//
// When Adapty bumps the fallback paywalls format alongside an SDK upgrade,
// bump MIN_VERSION below in the same PR that refreshes the JSONs (and the
// adapty_flutter dep in common/pubspec.yaml).

import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import process from "node:process";

const MIN_VERSION = 9;

const FILES = [
  "common/assets/fallbacks/ios.json",
  "common/assets/fallbacks/android.json",
  "android/app/src/main/assets/fallbacks/android.json",
];

let failed = false;

// The pubspec pins adapty_flutter exactly, but a dependency_overrides entry
// points it at the vendored copy in common/vendor/adapty_flutter (a stub
// podspec works around flutter/flutter#184590). A Dependabot bump edits only
// the pin, so without this check the app would silently keep building the old
// vendored version — the same illusory-bump trap as an unenforced lockfile.
const pubspec = readFileSync(resolve("common/pubspec.yaml"), "utf8");
// Require a version-shaped value so the bare `adapty_flutter:` key under
// dependency_overrides (a path block, no inline value) can never match,
// regardless of section order or indentation.
const pinned = pubspec.match(/^\s+adapty_flutter:\s*(\d\S*)\s*$/m)?.[1];
const vendored = readFileSync(
  resolve("common/vendor/adapty_flutter/pubspec.yaml"),
  "utf8",
).match(/^version:\s*(\S+)\s*$/m)?.[1];
const stubPodspec = readFileSync(
  resolve("common/vendor/adapty_flutter/ios/adapty_flutter.podspec"),
  "utf8",
).match(/s\.version\s*=\s*'([^']+)'/)?.[1];
if (!pinned || !vendored || !stubPodspec) {
  console.error(
    `FAIL  adapty_flutter version not found (pubspec pin: ${pinned}, ` +
      `vendored: ${vendored}, stub podspec: ${stubPodspec})`,
  );
  failed = true;
} else if (pinned !== vendored || pinned !== stubPodspec) {
  console.error(
    `FAIL  adapty_flutter versions out of lockstep: pin ${pinned}, vendored ` +
      `${vendored}, stub podspec ${stubPodspec} — refresh ` +
      "common/vendor/adapty_flutter from the new pub.dev release and keep " +
      "the vendor patches: stub podspec (bump its s.version), " +
      "BlokadaVendorAlias.swift, and the ios Package.swift AdaptySDK-iOS " +
      "pin (blokadaorg fork until the footer-gate regression is fixed " +
      "upstream)",
  );
  failed = true;
} else {
  console.log(`OK    adapty_flutter ${pinned} matches vendored copy and stub podspec`);
}

for (const rel of FILES) {
  const path = resolve(rel);
  let json;
  try {
    json = JSON.parse(readFileSync(path, "utf8"));
  } catch (e) {
    console.error(`FAIL  ${rel}  could not parse: ${e.message}`);
    failed = true;
    continue;
  }
  const version = json?.meta?.version;
  if (typeof version !== "number") {
    console.error(`FAIL  ${rel}  meta.version is missing or not a number`);
    failed = true;
    continue;
  }
  if (version < MIN_VERSION) {
    console.error(`FAIL  ${rel}  meta.version=${version}, expected >= ${MIN_VERSION}`);
    failed = true;
    continue;
  }
  console.log(`OK    ${rel}  meta.version=${version}`);
}

if (failed) {
  console.error("");
  console.error("Refresh fallback paywalls from the Adapty Dashboard and replace all three files.");
  console.error("If the Adapty SDK was upgraded, also bump MIN_VERSION in this script to match the new format.");
  process.exit(1);
}
