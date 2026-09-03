#!/usr/bin/env bash
#
# check_module_boundaries.sh
# --------------------------
# Defence-in-depth guard for the feature-package boundary (Source Spec §9.3).
# The primary mechanism is the SPM dependency graph + ArchTests rule K1; this
# grep is the second net.
#
# For every Packages/Features/<X>/, scan its Sources/**/*.swift for a top-level
#   import <Y>
# where <Y> is another feature package's module name (module names are derived
# from the Packages/Features/* directory names). Any edge X->Y that is not listed
# in scripts/module_boundary_whitelist.txt is a VIOLATION and exits 1.
#
# Commented-out imports (`// import Y`) are ignored: the match anchors on
# `^\s*import`.
#
# No Packages/Features/ (or an empty one) => nothing to check, exit 0.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
features_dir="$repo_root/Packages/Features"
whitelist_file="$repo_root/scripts/module_boundary_whitelist.txt"

if [[ ! -d "$features_dir" ]]; then
  echo "check_module_boundaries: no feature packages yet (Packages/Features/ absent) — nothing to check."
  exit 0
fi

feature_names=()
while IFS= read -r dir; do
  [[ -n "$dir" ]] && feature_names+=("$(basename "$dir")")
done < <(find "$features_dir" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#feature_names[@]} -eq 0 ]]; then
  echo "check_module_boundaries: no feature packages yet (Packages/Features/ empty) — nothing to check."
  exit 0
fi

# Load whitelist edges "X->Y" (strip inline # comments and all whitespace).
whitelist=()
if [[ -f "$whitelist_file" ]]; then
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    entry="${raw%%#*}"
    entry="$(printf '%s' "$entry" | tr -d '[:space:]')"
    [[ -n "$entry" ]] && whitelist+=("$entry")
  done <"$whitelist_file"
fi

is_whitelisted() {
  local edge="$1" candidate
  for candidate in ${whitelist[@]+"${whitelist[@]}"}; do
    [[ "$candidate" == "$edge" ]] && return 0
  done
  return 1
}

violations=0
for feature_path in "$features_dir"/*/; do
  [[ -d "$feature_path" ]] || continue
  from="$(basename "$feature_path")"
  sources_dir="${feature_path}Sources"
  [[ -d "$sources_dir" ]] || continue

  for other in "${feature_names[@]}"; do
    [[ "$other" == "$from" ]] && continue
    if grep -rEq "^[[:space:]]*import[[:space:]]+${other}([[:space:]]|$)" \
      --include='*.swift' "$sources_dir"; then
      edge="${from}->${other}"
      if is_whitelisted "$edge"; then
        echo "check_module_boundaries: ALLOWED (whitelisted) ${edge}"
      else
        echo "VIOLATION: ${from} imports ${other}"
        violations=$((violations + 1))
      fi
    fi
  done
done

if [[ "$violations" -gt 0 ]]; then
  echo "check_module_boundaries: ${violations} boundary violation(s) — see VIOLATION lines above." >&2
  exit 1
fi

echo "check_module_boundaries: OK — no cross-feature imports outside the whitelist."
exit 0
