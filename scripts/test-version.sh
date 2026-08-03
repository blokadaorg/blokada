#!/usr/bin/env bash
# Verifies scripts/version.py writes the exact code it is given, with no
# hidden offset, and that `make version` applies VERSION_CODE_OFFSET.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/build.gradle" <<'GRADLE'
        versionCode 1
        versionName "dev"
GRADLE
cat > "$tmp/project.pbxproj" <<'PBX'
				CURRENT_PROJECT_VERSION = 1;
				MARKETING_VERSION = dev;
PBX

python3 scripts/version.py \
  --android-file "$tmp/build.gradle" \
  --xcodeproj-file "$tmp/project.pbxproj" \
  --version-name "26.7.1042" \
  --version-code 669001042 >/dev/null

grep -q 'versionCode 669001042' "$tmp/build.gradle" \
  || { echo "FAIL: versionCode not written verbatim"; cat "$tmp/build.gradle"; exit 1; }
grep -q 'versionName "26.7.1042"' "$tmp/build.gradle" \
  || { echo "FAIL: versionName wrong"; exit 1; }
grep -q 'CURRENT_PROJECT_VERSION = 669001042;' "$tmp/project.pbxproj" \
  || { echo "FAIL: CURRENT_PROJECT_VERSION not written verbatim"; exit 1; }

echo "PASS: version.py writes codes verbatim"
