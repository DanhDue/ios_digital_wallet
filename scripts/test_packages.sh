#!/usr/bin/env bash
# scripts/test_packages.sh
# Runs unit tests for all local packages and features declared in Packages/ and Features/.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

shopt -s nullglob
tested=0

for dir in Packages/* Features/*; do
  [ -f "$dir/Package.swift" ] || continue
  tested=1
  echo "== Testing package: $dir =="
  swift test --package-path "$dir"
done

if [ "$tested" -eq 0 ]; then
  echo "❌ Error: No local packages found to test in Packages/ or Features/."
  exit 1
fi

echo "✅ All local package unit tests passed."
