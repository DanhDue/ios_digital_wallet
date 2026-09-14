#!/usr/bin/env bash
# scripts/test_bootstrap_devbed.sh
# Test harness for scripts/bootstrap_devbed.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/test_bootstrap_devbed.XXXXXX")
trap 'rm -rf "$TEST_TMPDIR"' EXIT

echo "=== Running bootstrap_devbed.sh test harness in $TEST_TMPDIR ==="

setup_test_repo() {
    local target="$1"
    mkdir -p "$target"
    (cd "$REPO_ROOT" && git archive HEAD) | (cd "$target" && tar -x)
    (cd "$REPO_ROOT" && git ls-files -m -o --exclude-standard) | while read -r f; do
        if [ -f "$REPO_ROOT/$f" ]; then
            mkdir -p "$target/$(dirname "$f")"
            cp "$REPO_ROOT/$f" "$target/$f"
        fi
    done
}

TARGET_DIR="$TEST_TMPDIR/repo"
setup_test_repo "$TARGET_DIR"
BOOTSTRAP_SCRIPT="$TARGET_DIR/scripts/bootstrap_devbed.sh"

if [ ! -f "$BOOTSTRAP_SCRIPT" ]; then
    echo "RED phase: scripts/bootstrap_devbed.sh does not exist yet." >&2
    exit 1
fi
chmod +x "$BOOTSTRAP_SCRIPT"

# Create a mock SDK with xcframework
MOCK_SDK_VALID="$TEST_TMPDIR/mock_sdk_valid"
mkdir -p "$MOCK_SDK_VALID/bin/cache/artifacts/engine/ios/Flutter.xcframework"
mkdir -p "$MOCK_SDK_VALID/bin/internal"
echo "3.41.1" > "$MOCK_SDK_VALID/bin/cache/flutter.version.json"
echo "engine12345" > "$MOCK_SDK_VALID/bin/internal/engine.version"

# Create a mock SDK missing xcframework
MOCK_SDK_INVALID="$TEST_TMPDIR/mock_sdk_invalid"
mkdir -p "$MOCK_SDK_INVALID/bin/internal" "$MOCK_SDK_INVALID/bin/cache"
echo "3.41.1" > "$MOCK_SDK_INVALID/bin/cache/flutter.version.json"

echo "--- Test 1: Missing SDK fails actionably ---"
if env -u FLUTTER_ROOT HOME="$TEST_TMPDIR/fake_home" PATH="/usr/bin:/bin" "$BOOTSTRAP_SCRIPT" --root-dir="$TARGET_DIR" 2>"$TEST_TMPDIR/no_sdk.log"; then
    echo "FAILED: Script succeeded when no Flutter SDK was available" >&2
    exit 1
fi
if ! grep -qi "FLUTTER_ROOT" "$TEST_TMPDIR/no_sdk.log"; then
    echo "FAILED: Expected error message to mention FLUTTER_ROOT" >&2
    cat "$TEST_TMPDIR/no_sdk.log" >&2
    exit 1
fi
echo "PASS: Missing SDK fails actionably"

echo "--- Test 2: SDK without iOS artifacts fails clearly with precache hint ---"
if "$BOOTSTRAP_SCRIPT" --flutter-root="$MOCK_SDK_INVALID" --root-dir="$TARGET_DIR" 2>"$TEST_TMPDIR/no_ios.log"; then
    echo "FAILED: Script succeeded on SDK missing iOS engine artifacts" >&2
    exit 1
fi
if ! grep -qi "precache" "$TEST_TMPDIR/no_ios.log"; then
    echo "FAILED: Expected error message to suggest 'flutter precache --ios'" >&2
    cat "$TEST_TMPDIR/no_ios.log" >&2
    exit 1
fi
echo "PASS: SDK without iOS artifacts suggests precache"

echo "--- Test 3: Bootstrap succeeds with --flutter-root override ---"
"$BOOTSTRAP_SCRIPT" --flutter-root="$MOCK_SDK_VALID" --root-dir="$TARGET_DIR"
if [ ! -L "$TARGET_DIR/Plugin/Vendor/Flutter.xcframework" ]; then
    echo "FAILED: Plugin/Vendor/Flutter.xcframework was not created as a symlink" >&2
    exit 1
fi
TARGET=$(readlink "$TARGET_DIR/Plugin/Vendor/Flutter.xcframework")
if [ "$TARGET" != "$MOCK_SDK_VALID/bin/cache/artifacts/engine/ios/Flutter.xcframework" ]; then
    echo "FAILED: Symlink targets '$TARGET', expected '$MOCK_SDK_VALID/bin/cache/artifacts/engine/ios/Flutter.xcframework'" >&2
    exit 1
fi
echo "PASS: --flutter-root created correct symlink"

echo "--- Test 4: Idempotency ---"
"$BOOTSTRAP_SCRIPT" --flutter-root="$MOCK_SDK_VALID" --root-dir="$TARGET_DIR"
if [ ! -L "$TARGET_DIR/Plugin/Vendor/Flutter.xcframework" ]; then
    echo "FAILED: Symlink missing after second run" >&2
    exit 1
fi
echo "PASS: Bootstrap is idempotent"

echo "--- Test 5: FLUTTER_ROOT env var resolution ---"
rm -rf "$TARGET_DIR/Plugin/Vendor"
FLUTTER_ROOT="$MOCK_SDK_VALID" "$BOOTSTRAP_SCRIPT" --root-dir="$TARGET_DIR"
if [ ! -L "$TARGET_DIR/Plugin/Vendor/Flutter.xcframework" ]; then
    echo "FAILED: Symlink not created via FLUTTER_ROOT env var" >&2
    exit 1
fi
echo "PASS: FLUTTER_ROOT env var resolved successfully"

echo "=== All bootstrap_devbed.sh tests passed! ==="
