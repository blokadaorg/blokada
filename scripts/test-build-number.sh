#!/usr/bin/env bash
# Exercises the allocator against a throwaway local "remote".
set -euo pipefail
SCRIPT="$(cd "$(dirname "$0")" && pwd)/build-number.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git init --quiet --bare "$tmp/remote.git"
git init --quiet "$tmp/work"
cd "$tmp/work"
git config user.email t@example.com
git config user.name Test
git remote add origin "$tmp/remote.git"
git commit --quiet --allow-empty -m init
git push --quiet origin HEAD:refs/heads/main

# First allocation starts at the floor.
out=$("$SCRIPT" allocate --start 1000)
echo "$out" | grep -qx 'build_number=1000' || { echo "FAIL: first allocate: $out"; exit 1; }
echo "$out" | grep -qE '^version_name=[0-9]{2}\.[0-9]{1,2}\.1000$' || { echo "FAIL: version_name: $out"; exit 1; }

# Second allocation increments.
out=$("$SCRIPT" allocate --start 1000)
echo "$out" | grep -qx 'build_number=1001' || { echo "FAIL: second allocate: $out"; exit 1; }

# Sorting is numeric, not lexicographic: 1002 must follow 1001, and later 1010 > 1009.
git tag -a build/1009 -m "26.7.1009" && git push --quiet origin build/1009
out=$("$SCRIPT" allocate --start 1000)
echo "$out" | grep -qx 'build_number=1010' || { echo "FAIL: numeric sort: $out"; exit 1; }

# resolve returns the stored version name, not a recomputed one.
git tag -a build/2000 -m "99.1.2000" && git push --quiet origin build/2000
out=$("$SCRIPT" resolve 2000)
echo "$out" | grep -qx 'build_number=2000' || { echo "FAIL: resolve number: $out"; exit 1; }
echo "$out" | grep -qx 'version_name=99.1.2000' || { echo "FAIL: resolve must read the annotation: $out"; exit 1; }

# resolve latest picks the numeric maximum.
out=$("$SCRIPT" resolve latest)
echo "$out" | grep -qx 'build_number=2000' || { echo "FAIL: resolve latest: $out"; exit 1; }

# resolve of a missing tag fails loudly.
if "$SCRIPT" resolve 4242 >/dev/null 2>&1; then
  echo "FAIL: resolve of a missing tag should exit non-zero"; exit 1
fi

echo "PASS: build-number.sh"
