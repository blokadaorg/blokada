#!/usr/bin/env bash
#
# Verify that every framework embedded in a built .ipa carries a valid code
# signature, before it is uploaded to App Store Connect.
#
# Why this exists:
#   scripts/sign-ios-frameworks.sh signs the *unsigned* third-party plugin
#   xcframeworks (sqflite_darwin, path_provider, shared_preferences, Adapty*)
#   to satisfy ITMS-91065, and deliberately does NOT touch Flutter's own
#   Flutter.framework / App.framework (they ship pre-signed; re-signing them
#   breaks Xcode's ProcessXCFramework/SignatureCollection step). This check
#   proves that assumption end-to-end: it cracks open the final .ipa and
#   confirms EVERY embedded framework — Flutter and App included — is signed,
#   so a missing signature is caught here instead of by App Store Connect.
#
# Usage: verify-ios-ipa-signatures.sh <path-to.ipa> [more.ipa ...]
#
# Kept POSIX-bash-3.2 friendly (no mapfile/readarray) so it runs under the
# stock /bin/bash on the CI runner as well as a newer bash.
set -euo pipefail

if [ "$#" -eq 0 ]; then
	echo "usage: $0 <path-to.ipa> [more.ipa ...]" >&2
	exit 2
fi

# Frameworks that MUST be present and signed in an add-to-app .ipa. Their
# absence would make an "all signed" pass vacuously true, so assert them.
REQUIRED_FRAMEWORKS=(Flutter.framework App.framework)

# A valid-but-wrong signature (ad-hoc, or a development cert) passes
# `codesign --verify` yet App Store Connect still rejects it, so also assert the
# signing authority is the App Store distribution identity. Substring match, to
# tolerate the team-id suffix. Set IOS_EXPECTED_SIGN_AUTHORITY="" to check
# presence only (e.g. when verifying a non-distribution build).
EXPECTED_AUTHORITY="${IOS_EXPECTED_SIGN_AUTHORITY-Apple Distribution}"

base="$(mktemp -d)"
trap 'rm -rf "$base"' EXIT

status=0
for ipa in "$@"; do
	if [ ! -f "$ipa" ]; then
		echo "error: ipa not found: $ipa" >&2
		exit 1
	fi

	echo "verify-ios-ipa-signatures: inspecting $ipa"
	workdir="$base/$(basename "$ipa").extracted"
	mkdir -p "$workdir"
	unzip -q "$ipa" -d "$workdir"

	# Every embedded framework anywhere in the payload — the .app and any nested
	# .appex plug-ins (e.g. the WireGuard network extension).
	frameworks="$(find "$workdir/Payload" -type d -name '*.framework' 2>/dev/null | sort || true)"
	if [ -z "$frameworks" ]; then
		echo "error: no embedded frameworks found in $ipa (unexpected)" >&2
		exit 1
	fi

	unsigned=0
	total=0
	seen=""
	while IFS= read -r fw; do
		[ -z "$fw" ] && continue
		total=$((total + 1))
		name="$(basename "$fw")"
		seen="$seen
$name"
		# `codesign --verify` fails both for a missing signature ("not signed at
		# all" → ITMS-91065) and for a broken seal, so it is the right gate.
		# Capture once (stderr carries the reason on failure).
		#
		# NB: everything below parses captured strings via here-strings / bash
		# builtins, never `cmd | awk/grep/head`. With `set -o pipefail`, a
		# downstream consumer that exits early (awk `exit`, grep -q, head) closes
		# the pipe and the producer (e.g. codesign) dies with SIGPIPE → the
		# pipeline returns 141 and `set -e` kills the whole script. That is
		# exactly what broke the first release attempt (make ... Error 141).
		if verr="$(codesign --verify --strict "$fw" 2>&1)"; then
			info="$(codesign -dvv "$fw" 2>&1 || true)"
			authority="$(awk -F'=' '/^Authority=/{print $2; exit}' <<< "$info")"
			if [ -n "$EXPECTED_AUTHORITY" ]; then
				case "$authority" in
					*"$EXPECTED_AUTHORITY"*)
						echo "  OK   $name  [${authority:-no authority line}]" ;;
					*)
						echo "  FAIL $name  — signed by '${authority:-no authority}', expected authority containing '$EXPECTED_AUTHORITY'" >&2
						unsigned=$((unsigned + 1)) ;;
				esac
			else
				echo "  OK   $name  [${authority:-no authority line}]"
			fi
		else
			echo "  FAIL $name  — ${verr%%$'\n'*}" >&2
			unsigned=$((unsigned + 1))
		fi
	done <<< "$frameworks"

	# Fail loudly if a framework we expect to be embedded is missing entirely.
	# `grep` reads a here-string (not a pipeline), so its early exit on a match
	# cannot trigger the SIGPIPE/pipefail trap described above.
	for req in "${REQUIRED_FRAMEWORKS[@]}"; do
		if ! grep -qx "$req" <<< "$seen"; then
			echo "  MISSING $req — expected to be embedded but not found in $ipa" >&2
			unsigned=$((unsigned + 1))
		fi
	done

	if [ "$unsigned" -ne 0 ]; then
		echo "verify-ios-ipa-signatures: $unsigned unsigned/missing framework(s) in $ipa — App Store would reject (ITMS-91065)" >&2
		status=1
	else
		echo "verify-ios-ipa-signatures: all $total embedded framework(s) signed in $ipa"
	fi
done

exit "$status"
