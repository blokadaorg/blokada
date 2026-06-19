#!/usr/bin/env bash
#
# Sign the add-to-app Flutter plugin XCFRAMEWORK BUNDLES (with a secure
# timestamp) before the host Xcode archive consumes them.
#
# Why this exists / what ITMS-91065 actually checks:
#   `flutter build ios-framework` (see common/Makefile `build-ios`) emits every
#   plugin as an UNSIGNED .xcframework. App Store Connect then rejects the upload
#   with ITMS-91065 ("Missing signature") for commonly-used third-party SDKs such
#   as sqflite (sqflite_darwin), path_provider and shared_preferences.
#
#   ITMS-91065 does NOT check the embedded framework's code signature — Xcode's
#   embed/export step code-signs that on copy (verified separately by
#   scripts/verify-ios-ipa-signatures.sh). It checks the XCFRAMEWORK's own
#   *origin* signature, which the archive records into the IPA at
#   `Signatures/<name>.xcframework-ios.signature` as `signed` / `isSecureTimestamp`.
#   An unsigned .xcframework yields `signed=false` → ITMS-91065. (This is the
#   feature documented in "Verifying the origin of your XCFrameworks", the page
#   Apple's rejection email links to.)
#
#   The fix is Apple's canonical command — also the sqflite maintainer's accepted
#   resolution (tekartik/sqflite#1129): sign the .xcframework *bundle* WITH
#   `--timestamp`, so the recorded origin signature has `signed=true` AND
#   `isSecureTimestamp=true`. Signing the inner per-slice .framework does NOT
#   satisfy this (wrong artifact; the export re-signs it anyway) and additionally
#   broke the archive's SignatureCollection step for Flutter (release 26.2.18).
#
# Scope: release archive targets only (build-ios / build-ios-family /
#   build-ios-six). `--timestamp` contacts Apple's timestamp server, so this step
#   needs network at build time.
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

# Do NOT sign Flutter's own first-party xcframeworks. Flutter.xcframework already
# carries a valid origin signature (Google signs it) and re-signing it breaks the
# archive's SignatureCollection step (release 26.2.18). App.xcframework is the
# app's own Dart code and FlutterPluginRegistrant is static/link-only — neither
# is a third-party SDK, so ITMS-91065 never flags them.
EXCLUDED_XCFRAMEWORKS=(Flutter App FlutterPluginRegistrant)

is_excluded() {
	local n="$1" ex
	for ex in "${EXCLUDED_XCFRAMEWORKS[@]}"; do
		[ "$n" = "$ex" ] && return 0
	done
	return 1
}

echo "sign-ios-frameworks: signing $CONFIG plugin xcframeworks (with secure timestamp) as '$IDENTITY'"

shopt -s nullglob
signed=0
for xcf in "$FRAMEWORK_DIR"/*.xcframework; do
	name="$(basename "$xcf" .xcframework)"
	is_excluded "$name" && continue

	# Sign the bundle. `--timestamp` is REQUIRED: the origin signature must record
	# isSecureTimestamp=true (codesign contacts Apple's TSA → needs network).
	# `--force` is idempotent — overwrites any signature from a prior run.
	codesign --force --timestamp -v --sign "$IDENTITY" "$xcf"

	# Verify before the archive consumes it: a valid signature AND a secure
	# timestamp present, so a TSA failure is caught here rather than at upload.
	# `grep` reads a here-string (not a pipeline) to avoid a SIGPIPE/pipefail abort.
	codesign --verify --strict "$xcf"
	if ! grep -q '^Timestamp=' <<< "$(codesign -dvv "$xcf" 2>&1 || true)"; then
		echo "error: $name.xcframework signed without a secure timestamp (Apple TSA unreachable?)" >&2
		exit 1
	fi
	echo "  signed $name.xcframework (secure timestamp)"
	signed=$((signed + 1))
done

if [ "$signed" -eq 0 ]; then
	echo "error: no plugin .xcframework bundles found under $FRAMEWORK_DIR" >&2
	exit 1
fi

echo "sign-ios-frameworks: signed & verified $signed plugin xcframework(s) with secure timestamp"
