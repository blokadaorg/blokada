#!/usr/bin/env bash
# Fails if any lib/ file imports the package by its absolute name. Such imports break when the
# tree is republished under a different package name (adapty_flutter_kids).
set -euo pipefail
cd "$(dirname "$0")/.."
hits=$(grep -rn "package:adapty_flutter/" lib/ || true)
if [ -n "$hits" ]; then
  echo "Absolute self-imports found (use relative imports instead):"
  echo "$hits"
  exit 1
fi
echo "OK: no absolute self-imports in lib/"
