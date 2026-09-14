#!/usr/bin/env bash
# scripts/bootstrap_devbed.sh
# Bootstraps the Flutter Engine binding for the iOS Plugin DevBed.
# Resolves the Flutter SDK, verifies engine artifacts, and symlinks
# Flutter.xcframework into Plugin/Vendor/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

FLUTTER_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --flutter-root=*)
      FLUTTER_OVERRIDE="${1#*=}"
      shift
      ;;
    --flutter-root)
      shift
      [ $# -gt 0 ] || { echo "bootstrap_devbed: missing argument for --flutter-root" >&2; exit 1; }
      FLUTTER_OVERRIDE="$1"
      shift
      ;;
    --root-dir=*)
      ROOT_DIR="${1#*=}"
      shift
      ;;
    --root-dir)
      shift
      [ $# -gt 0 ] || { echo "bootstrap_devbed: missing argument for --root-dir" >&2; exit 1; }
      ROOT_DIR="$1"
      shift
      ;;
    -h|--help)
      echo "usage: ./scripts/bootstrap_devbed.sh [--flutter-root=<path>] [--root-dir=<path>]"
      exit 0
      ;;
    *)
      echo "bootstrap_devbed: unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

die() {
  echo "bootstrap_devbed: $1" >&2
  exit 1
}

# --- Resolution order: --flutter-root, $FLUTTER_ROOT, fvm, which flutter ---
resolve_flutter_sdk() {
  if [ -n "$FLUTTER_OVERRIDE" ] && [ -d "$FLUTTER_OVERRIDE" ]; then
    echo "$FLUTTER_OVERRIDE"
    return 0
  fi

  if [ -n "${FLUTTER_ROOT:-}" ] && [ -d "$FLUTTER_ROOT" ]; then
    echo "$FLUTTER_ROOT"
    return 0
  fi

  # Check fvm configuration or standard fvm locations
  if [ -f "$ROOT_DIR/.fvmrc" ]; then
    local fvm_ver
    fvm_ver="$(python3 -c "import json; print(json.load(open('$ROOT_DIR/.fvmrc')).get('flutter', ''))" 2>/dev/null || true)"
    if [ -n "$fvm_ver" ]; then
      for candidate in "$HOME/fvm/versions/$fvm_ver" "$HOME/.fvm/versions/$fvm_ver"; do
        if [ -d "$candidate" ]; then
          echo "$candidate"
          return 0
        fi
      done
    fi
  fi

  for default_fvm in "$HOME/fvm/default" "$HOME/.fvm/default"; do
    if [ -d "$default_fvm" ]; then
      echo "$default_fvm"
      return 0
    fi
  done

  # Fallback to which flutter resolved through symlinks
  if which flutter >/dev/null 2>&1; then
    local flutter_bin
    flutter_bin="$(which flutter)"
    local real_root
    real_root="$(python3 -c "import os, sys; print(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[1]))))" "$flutter_bin" 2>/dev/null || true)"
    if [ -n "$real_root" ] && [ -d "$real_root" ]; then
      echo "$real_root"
      return 0
    fi
  fi

  return 1
}

RESOLVED_SDK="$(resolve_flutter_sdk || true)"

if [ -z "$RESOLVED_SDK" ] || [ ! -d "$RESOLVED_SDK" ]; then
  die "No Flutter SDK found via --flutter-root, FLUTTER_ROOT, fvm, or PATH. Set FLUTTER_ROOT or pass --flutter-root=<path>."
fi

ENGINE_XCFRAMEWORK="$RESOLVED_SDK/bin/cache/artifacts/engine/ios/Flutter.xcframework"

if [ ! -d "$ENGINE_XCFRAMEWORK" ]; then
  die "Flutter SDK found at '$RESOLVED_SDK', but bin/cache/artifacts/engine/ios/Flutter.xcframework does not exist. Run 'flutter precache --ios' to download iOS engine artifacts."
fi

# Create target symlink
VENDOR_DIR="$ROOT_DIR/Plugin/Vendor"
mkdir -p "$VENDOR_DIR"
ln -sfn "$ENGINE_XCFRAMEWORK" "$VENDOR_DIR/Flutter.xcframework"

# Extract versions for drift visibility
FLUTTER_VERSION="unknown"
if [ -f "$RESOLVED_SDK/bin/cache/flutter.version.json" ]; then
  FLUTTER_VERSION="$(python3 -c "import json; data=json.load(open('$RESOLVED_SDK/bin/cache/flutter.version.json')); print(data.get('flutterVersion') or data.get('frameworkVersion') or 'unknown')" 2>/dev/null || echo "unknown")"
elif [ -f "$RESOLVED_SDK/version" ]; then
  FLUTTER_VERSION="$(cat "$RESOLVED_SDK/version")"
fi

ENGINE_VERSION="unknown"
if [ -f "$RESOLVED_SDK/bin/internal/engine.version" ]; then
  ENGINE_VERSION="$(cat "$RESOLVED_SDK/bin/internal/engine.version" | tr -d '[:space:]')"
elif [ -f "$RESOLVED_SDK/bin/cache/flutter.version.json" ]; then
  ENGINE_VERSION="$(python3 -c "import json; print(json.load(open('$RESOLVED_SDK/bin/cache/flutter.version.json')).get('engineRevision', 'unknown'))" 2>/dev/null || echo "unknown")"
fi

echo "bootstrap_devbed: Flutter SDK: $RESOLVED_SDK"
echo "bootstrap_devbed: Flutter version: $FLUTTER_VERSION"
echo "bootstrap_devbed: Engine version:  $ENGINE_VERSION"
echo "bootstrap_devbed: Symlinked Flutter.xcframework -> Plugin/Vendor/Flutter.xcframework"
