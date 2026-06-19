#!/usr/bin/env bash
#
# Code-sign the add-to-app Flutter plugin xcframeworks before the host Xcode
# archive embeds them.
#
# Why this exists:
#   `flutter build ios-framework` (see common/Makefile `build-ios`) emits every
#   plugin as an UNSIGNED .xcframework. The host project embeds each with
#   "Code Sign On Copy", but that runtime re-sign is unreliable for the device
#   slice of a pre-built xcframework (flutter/flutter#148300, #179634), so the
#   embedded framework can ship unsigned. App Store Connect then rejects the
#   upload with ITMS-91065 ("Missing signature") for commonly-used SDKs such as
#   sqflite (sqflite_darwin.framework), path_provider and shared_preferences.
#
#   Signing the inner .framework of each slice here guarantees a valid signature
#   is present regardless of whether Code-Sign-On-Copy runs: if Xcode re-signs on
#   copy it harmlessly overwrites ours with the same Apple Distribution identity;
#   if it skips the slice, our signature is what ships. Signing the .xcframework
#   *wrapper* is NOT enough — it does not propagate to the inner frameworks that
#   actually land in the app bundle.
#
# Scope: only used by the release archive targets in the root Makefile
# (build-ios / build-ios-family / build-ios-six). Debug/simulator builds sign via
# the normal dev identity on copy and do not go through here.
#
# Override the signing identity or config via env:
#   IOS_CODESIGN_IDENTITY="Apple Distribution: ... (TEAMID)"  CONFIG=Release
set -euo pipefail

CONFIG="${CONFIG:-Release}"
# Default to the Blocka AB App Store distribution cert. This is the same team as
# the host app's `match AppStore` profiles (ios/fastlane/); if `match` ever
# provisions a differently-named cert, override with IOS_CODESIGN_IDENTITY.
IDENTITY="${IOS_CODESIGN_IDENTITY:-Apple Distribution: Blocka AB (HQH5AFGB68)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
FRAMEWORK_DIR="$ROOT_DIR/common/build/ios-framework/$CONFIG"

if [ ! -d "$FRAMEWORK_DIR" ]; then
	echo "error: $FRAMEWORK_DIR not found — run 'make -C common build-ios' first." >&2
	exit 1
fi

# Preflight: fail with a clear message up front rather than an opaque codesign
# error deep in the signing loop if the cert isn't available on this machine.
if ! security find-identity -v -p codesigning 2>/dev/null | grep -qF "$IDENTITY"; then
	echo "error: signing identity not found in keychain: '$IDENTITY'" >&2
	echo "       unlock/import the App Store distribution cert, or set" >&2
	echo "       IOS_CODESIGN_IDENTITY to the identity to use." >&2
	exit 1
fi

# Gather the framework list first (tolerating a transient find error via `|| true`)
# so the producer pipeline's exit status can't abort the run mid-loop under
# `pipefail`. Sort deepest-first so any nested frameworks are signed before their
# container (inside-out signing); the awk field is the slash count = path depth.
frameworks="$(find "$FRAMEWORK_DIR" -type d -name '*.framework' 2>/dev/null \
	| awk '{ print gsub(/\//, "/"), $0 }' | sort -rn | cut -d' ' -f2- || true)"

if [ -z "$frameworks" ]; then
	echo "error: no .framework bundles found under $FRAMEWORK_DIR" >&2
	exit 1
fi

echo "sign-ios-frameworks: signing $CONFIG plugin frameworks as '$IDENTITY'"

# `codesign --force` is idempotent — the frameworks may already carry a
# _CodeSignature from a prior run; re-signing cleanly overwrites it.
signed=0
while IFS= read -r fw; do
	[ -z "$fw" ] && continue
	codesign --force -v --sign "$IDENTITY" "$fw"
	signed=$((signed + 1))
done <<< "$frameworks"

# Verify every framework before the host archive consumes them, so a corrupt
# signature is caught here rather than at App Store upload.
while IFS= read -r fw; do
	[ -z "$fw" ] && continue
	codesign --verify --strict "$fw"
done <<< "$frameworks"

echo "sign-ios-frameworks: signed & verified $signed framework(s)"
