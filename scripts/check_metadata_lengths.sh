#!/usr/bin/env bash
# Lint listing-metadata field lengths against App Store Connect / Play Console limits.
# Counts characters (not bytes) and ignores trailing newlines.
# Fails non-zero if any field exceeds its limit or is unexpectedly empty.

set -euo pipefail

cd "$(dirname "$0")/.."

fail=0

count_chars() {
  python3 -c "import sys; print(len(open(sys.argv[1], encoding='utf-8').read().rstrip('\n')))" "$1"
}

check_max() {
  local file="$1" max="$2"
  [[ -f "$file" ]] || return 0
  local len
  len=$(count_chars "$file")
  if (( len > max )); then
    echo "TOO LONG ($len > $max): $file"
    fail=1
  fi
}

check_nonempty() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local len
  len=$(count_chars "$file")
  if (( len < 1 )); then
    echo "EMPTY: $file"
    fail=1
  fi
}

# iOS: ios-six and ios-family
for flavor in ios-six ios-family; do
  for locale_dir in metadata/$flavor/*/; do
    [[ -d "$locale_dir" ]] || continue
    check_max "${locale_dir}name.txt" 30
    check_max "${locale_dir}subtitle.txt" 30
    check_max "${locale_dir}promotional_text.txt" 170
    check_max "${locale_dir}description.txt" 4000
    check_max "${locale_dir}keywords.txt" 100
    check_max "${locale_dir}release_notes.txt" 4000
    check_nonempty "${locale_dir}description.txt"
  done
done

# Android: android-six and android-family
for flavor in android-six android-family; do
  for locale_dir in metadata/$flavor/*/; do
    [[ -d "$locale_dir" ]] || continue
    check_max "${locale_dir}title.txt" 30
    check_max "${locale_dir}short_description.txt" 80
    check_max "${locale_dir}full_description.txt" 4000
    check_nonempty "${locale_dir}full_description.txt"
  done
done

if (( fail )); then
  echo ""
  echo "metadata length check FAILED"
  exit 1
fi

echo "metadata length check OK"
