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
