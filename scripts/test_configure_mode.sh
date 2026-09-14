#!/usr/bin/env bash
# scripts/test_configure_mode.sh
# Test harness for scripts/configure_mode.sh covering BDD scenarios S1-S8.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/test_configure_mode.XXXXXX")
trap 'rm -rf "$TEST_TMPDIR"' EXIT

echo "=== Running configure_mode.sh test harness in $TEST_TMPDIR ==="

# Helper to copy repo to isolated test directory
setup_test_repo() {
    local target="$1"
    mkdir -p "$target"
    # Copy repo tracked files using git archive or rsync/cp
    (cd "$REPO_ROOT" && git archive HEAD) | (cd "$target" && tar -x)
    # Also sync modified and untracked files from working tree
    (cd "$REPO_ROOT" && git ls-files -m -o --exclude-standard) | while read -r f; do
        if [ -f "$REPO_ROOT/$f" ]; then
            mkdir -p "$target/$(dirname "$f")"
            cp "$REPO_ROOT/$f" "$target/$f"
        fi
    done
    # Initialize a dummy git repo so git status works
    (
        cd "$target"
        git init -q
        git config user.name "Test Runner"
        git config user.email "test@example.com"
        "$target/scripts/configure_mode.sh" enterprise --root-dir="$target" --skip-tuist
        git add -A
        git commit -qm "Initial enterprise commit for test"
    )
}

TARGET_DIR="$TEST_TMPDIR/repo"
setup_test_repo "$TARGET_DIR"

CFG="$TARGET_DIR/scripts/configure_mode.sh"

if [ ! -f "$CFG" ]; then
    echo "RED phase: scripts/configure_mode.sh does not exist yet." >&2
    exit 1
fi

chmod +x "$CFG"

echo "--- Test 1: Invalid mode is rejected ---"
if "$CFG" turbo --root-dir="$TARGET_DIR" 2>/dev/null; then
    echo "FAILED: Invalid mode 'turbo' was accepted" >&2
    exit 1
fi
echo "PASS: Invalid mode rejected"

echo "--- Test 2: Two modes passed at once is rejected ---"
if "$CFG" lean enterprise --root-dir="$TARGET_DIR" 2>/dev/null; then
    echo "FAILED: Multiple modes were accepted" >&2
    exit 1
fi
echo "PASS: Multiple modes rejected"

echo "--- Test 3: --prune refuses dirty tree without --force ---"
touch "$TARGET_DIR/dirty_file.txt"
if "$CFG" lean --prune --root-dir="$TARGET_DIR" 2>/dev/null; then
    echo "FAILED: --prune executed on a dirty tree without --force" >&2
    exit 1
fi
rm -f "$TARGET_DIR/dirty_file.txt"
echo "PASS: --prune refused dirty tree"

echo "--- Test 4: Switch to lean mode unwires Scanner everywhere ---"
"$CFG" lean --root-dir="$TARGET_DIR" --skip-tuist

# Assert ActiveMode.swift
if ! grep -q 'activeMode: TemplateMode = .lean' "$TARGET_DIR/Tuist/ProjectDescriptionHelpers/ActiveMode.swift"; then
    echo "FAILED: ActiveMode.swift does not declare .lean" >&2
    exit 1
fi

# Assert AppComposition.swift
if ! grep -q '// import Scanner' "$TARGET_DIR/App/Sources/Composition/AppComposition.swift"; then
    echo "FAILED: AppComposition.swift did not comment out 'import Scanner'" >&2
    exit 1
fi

if ! grep -q '// let scannerProvider = ScannerRouteProvider' "$TARGET_DIR/App/Sources/Composition/AppComposition.swift"; then
    echo "FAILED: AppComposition.swift did not comment out scannerProvider" >&2
    exit 1
fi

# Assert ShellView.swift
if ! grep -q '// tabStack(index: 1) { router.destination(for: AppRoutes.ScannerRoot()) }' "$TARGET_DIR/Packages/Shell/Sources/Shell/ShellView.swift"; then
    echo "FAILED: ShellView.swift did not comment out scanner tab" >&2
    exit 1
fi

if ! grep -q 'tabStack(index: 1) { router.destination(for: AppRoutes.SettingsRoot()) }' "$TARGET_DIR/Packages/Shell/Sources/Shell/ShellView.swift"; then
    echo "FAILED: ShellView.swift did not update Settings to index 1" >&2
    exit 1
fi

# Assert DeepLinkComposition.swift
if ! grep -q '// case is AppRoutes.ScannerRoot:' "$TARGET_DIR/App/Sources/Composition/DeepLinkComposition.swift"; then
    echo "FAILED: DeepLinkComposition.swift did not comment out ScannerRoot case" >&2
    exit 1
fi

# Assert ShellConfig.swift
if ! grep -q 'tabCount: Int = 2, initialTab: Int = 1' "$TARGET_DIR/Packages/Shell/Sources/Shell/ShellConfig.swift"; then
    echo "FAILED: ShellConfig.swift does not have defaults tabCount: 2, initialTab: 1" >&2
    exit 1
fi

# Assert Packages/Shell/Package.swift exclude
if ! grep -q 'exclude: \["ScannerTabTests.swift"\]' "$TARGET_DIR/Packages/Shell/Package.swift"; then
    echo "FAILED: Packages/Shell/Package.swift does not exclude ScannerTabTests.swift in lean mode" >&2
    exit 1
fi
echo "PASS: Lean mode successfully unwires Scanner"

echo "--- Test 5: Idempotency in lean mode ---"
# Capture tree hash before second run
PRE_HASH=$(cd "$TARGET_DIR" && git diff | shasum -a 256)
"$CFG" lean --root-dir="$TARGET_DIR" --skip-tuist
POST_HASH=$(cd "$TARGET_DIR" && git diff | shasum -a 256)
if [ "$PRE_HASH" != "$POST_HASH" ]; then
    echo "FAILED: Second run of lean mode altered working tree" >&2
    exit 1
fi
echo "PASS: Lean mode is idempotent"

echo "--- Test 6: Switching back to enterprise restores everything ---"
"$CFG" enterprise --root-dir="$TARGET_DIR" --skip-tuist

if ! grep -q 'activeMode: TemplateMode = .enterprise' "$TARGET_DIR/Tuist/ProjectDescriptionHelpers/ActiveMode.swift"; then
    echo "FAILED: ActiveMode.swift does not declare .enterprise" >&2
    exit 1
fi

if grep -q '// import Scanner' "$TARGET_DIR/App/Sources/Composition/AppComposition.swift"; then
    echo "FAILED: AppComposition.swift still has commented out 'import Scanner'" >&2
    exit 1
fi

if grep -q '// let scannerProvider = ScannerRouteProvider' "$TARGET_DIR/App/Sources/Composition/AppComposition.swift"; then
    echo "FAILED: AppComposition.swift still has commented out scannerProvider" >&2
    exit 1
fi

if grep -q '// tabStack(index: 1) { router.destination(for: AppRoutes.ScannerRoot()) }' "$TARGET_DIR/Packages/Shell/Sources/Shell/ShellView.swift"; then
    echo "FAILED: ShellView.swift still has commented out scanner tab" >&2
    exit 1
fi

if ! grep -q 'tabStack(index: 2) { router.destination(for: AppRoutes.SettingsRoot()) }' "$TARGET_DIR/Packages/Shell/Sources/Shell/ShellView.swift"; then
    echo "FAILED: ShellView.swift did not restore Settings to index 2" >&2
    exit 1
fi

if grep -q '// case is AppRoutes.ScannerRoot:' "$TARGET_DIR/App/Sources/Composition/DeepLinkComposition.swift"; then
    echo "FAILED: DeepLinkComposition.swift still has commented out ScannerRoot case" >&2
    exit 1
fi

if ! grep -q 'tabCount: Int = 3, initialTab: Int = 2' "$TARGET_DIR/Packages/Shell/Sources/Shell/ShellConfig.swift"; then
    echo "FAILED: ShellConfig.swift did not restore defaults tabCount: 3, initialTab: 2" >&2
    exit 1
fi

if ! grep -q 'exclude: \[\]' "$TARGET_DIR/Packages/Shell/Package.swift"; then
    echo "FAILED: Packages/Shell/Package.swift did not restore exclude: [] in enterprise mode" >&2
    exit 1
fi
echo "PASS: Enterprise mode restores all marker regions and defaults"

echo "--- Test 7: --prune deletes unused feature directories and test files ---"
[ -d "$TARGET_DIR/Features/Scanner" ] || (echo "FAILED: Features/Scanner already missing" >&2 && exit 1)
"$CFG" lean --prune --root-dir="$TARGET_DIR" --skip-tuist
if [ -d "$TARGET_DIR/Features/Scanner" ]; then
    echo "FAILED: Features/Scanner was not pruned" >&2
    exit 1
fi
for f in \
    "Packages/Shell/Tests/ShellTests/ScannerTabTests.swift" \
    "App/Tests/AppTests/ScannerCompositionTests.swift" \
    "App/Tests/AppTests/ScannerDeepLinkTests.swift" \
    "App/UITests/ScannerTabUITests.swift"; do
    if [ -f "$TARGET_DIR/$f" ]; then
        echo "FAILED: $f was not pruned" >&2
        exit 1
    fi
done
echo "PASS: --prune successfully deleted Features/Scanner and extracted tests"

echo "=== All configure_mode.sh tests passed! ==="
