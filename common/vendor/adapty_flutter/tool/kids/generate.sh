#!/usr/bin/env bash
# Generate the adapty_flutter_kids package into <outdir> from the adapty_flutter tree.
# Usage: tool/kids/generate.sh <outdir>
set -euo pipefail
here="$(cd "$(dirname "$0")/../.." && pwd)"   # adapty_flutter package root
out="${1:?usage: generate.sh <outdir>}"

rm -rf "$out"
mkdir -p "$out"
# Copy the tree (real files). example/ is excluded: it depends on adapty_flutter by path and is
# not a valid kids consumer; .git / derived dirs are excluded too.
rsync -a \
  --exclude '.git' --exclude '.dart_tool' --exclude 'build' --exclude 'example' \
  "$here"/ "$out"/

# iOS SPM package dir must be named after the plugin.
mv "$out/ios/adapty_flutter" "$out/ios/adapty_flutter_kids"
cp "$here/tool/kids/Package.swift" "$out/ios/adapty_flutter_kids/Package.swift"

# pubspec: name/description; keep version (lockstep) and everything else.
dart "$here/tool/kids/pubspec.patch.dart" "$out/pubspec.yaml" > "$out/pubspec.yaml.tmp"
mv "$out/pubspec.yaml.tmp" "$out/pubspec.yaml"

cp "$here/tool/kids/.pubignore" "$out/.pubignore"
echo "Generated adapty_flutter_kids at: $out"
