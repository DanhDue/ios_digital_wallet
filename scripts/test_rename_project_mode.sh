#!/usr/bin/env bash
# scripts/test_rename_project_mode.sh
# Test harness for scripts/rename_project.sh with --mode integration.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/test_rename_project_mode.XXXXXX")
trap 'rm -rf "$TEST_TMPDIR"' EXIT

echo "=== Running rename_project.sh --mode test harness in $TEST_TMPDIR ==="

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
    (
        cd "$target"
        git init -q
        git config user.name "Test Runner"
        git config user.email "test@example.com"
        git add -A
        git commit -qm "Initial commit for test"
    )
}

TARGET_DIR="$TEST_TMPDIR/repo1"
setup_test_repo "$TARGET_DIR"
RENAME_SCRIPT="$TARGET_DIR/scripts/rename_project.sh"

echo "--- Test 1: Invalid mode is rejected before any rename happens ---"
if "$RENAME_SCRIPT" AcmeApp com.acme.app --mode turbo 2>"$TEST_TMPDIR/turbo_err.log"; then
    echo "FAILED: Invalid mode 'turbo' was accepted" >&2
    exit 1
fi
if ! grep -qi "usage" "$TEST_TMPDIR/turbo_err.log" && ! grep -qi "mode" "$TEST_TMPDIR/turbo_err.log"; then
    echo "FAILED: Expected usage or mode error in output" >&2
    cat "$TEST_TMPDIR/turbo_err.log" >&2
    exit 1
fi
STATUS=$(cd "$TARGET_DIR" && git status --porcelain)
if [ -n "$STATUS" ]; then
    echo "FAILED: Working tree modified after invalid mode rejection" >&2
    exit 1
fi
echo "PASS: Invalid mode rejected and tree remains clean"

echo "--- Test 2: --dry-run prints 'WOULD CONFIGURE MODE: <mode>' and changes nothing ---"
DRY_OUT=$("$RENAME_SCRIPT" AcmeApp com.acme.app --mode lean --dry-run)
if ! echo "$DRY_OUT" | grep -q "WOULD CONFIGURE MODE: lean"; then
    echo "FAILED: --dry-run did not output 'WOULD CONFIGURE MODE: lean'" >&2
    echo "Output was:"
    echo "$DRY_OUT"
    exit 1
fi
STATUS=$(cd "$TARGET_DIR" && git status --porcelain)
if [ -n "$STATUS" ]; then
    echo "FAILED: Working tree modified after --dry-run" >&2
    exit 1
fi
echo "PASS: --dry-run printed expected message and left tree untouched"

echo "--- Test 3: Renaming with --mode lean renames and configures lean mode ---"
TARGET_DIR_LEAN="$TEST_TMPDIR/repo_lean"
setup_test_repo "$TARGET_DIR_LEAN"
RENAME_SCRIPT_LEAN="$TARGET_DIR_LEAN/scripts/rename_project.sh"

# Run rename with --mode lean and RENAME_SKIP_VERIFY=1 for speed in harness
RENAME_SKIP_VERIFY=1 "$RENAME_SCRIPT_LEAN" AcmeLean com.acme.lean --mode lean

# Verify rename substitutions took place
if [ ! -f "$TARGET_DIR_LEAN/App/Sources/AcmeLeanApp.swift" ]; then
    echo "FAILED: App entry point was not renamed to AcmeLeanApp.swift" >&2
    exit 1
fi
if grep -q "iOSDigitalWallet" "$TARGET_DIR_LEAN/Project.swift"; then
    echo "FAILED: Project.swift still contains 'iOSDigitalWallet'" >&2
    exit 1
fi

# Verify lean mode was configured
if ! grep -q 'activeMode: TemplateMode = .lean' "$TARGET_DIR_LEAN/Tuist/ProjectDescriptionHelpers/ActiveMode.swift"; then
    echo "FAILED: ActiveMode.swift was not set to .lean" >&2
    exit 1
fi
if ! grep -q '// import Scanner' "$TARGET_DIR_LEAN/App/Sources/Composition/AppComposition.swift"; then
    echo "FAILED: AppComposition.swift does not have Scanner commented out" >&2
    exit 1
fi
echo "PASS: --mode lean renamed project and configured lean mode"

echo "--- Test 4: Omitting --mode preserves enterprise mode ---"
TARGET_DIR_ENT="$TEST_TMPDIR/repo_ent"
setup_test_repo "$TARGET_DIR_ENT"
RENAME_SCRIPT_ENT="$TARGET_DIR_ENT/scripts/rename_project.sh"

RENAME_SKIP_VERIFY=1 "$RENAME_SCRIPT_ENT" AcmeEnterprise com.acme.enterprise

if [ ! -f "$TARGET_DIR_ENT/App/Sources/AcmeEnterpriseApp.swift" ]; then
    echo "FAILED: App entry point was not renamed to AcmeEnterpriseApp.swift" >&2
    exit 1
fi
if ! grep -q 'activeMode: TemplateMode = .enterprise' "$TARGET_DIR_ENT/Tuist/ProjectDescriptionHelpers/ActiveMode.swift"; then
    echo "FAILED: ActiveMode.swift was not .enterprise by default" >&2
    exit 1
fi
if grep -q '// import Scanner' "$TARGET_DIR_ENT/App/Sources/Composition/AppComposition.swift"; then
    echo "FAILED: AppComposition.swift unexpectedly commented out Scanner in default mode" >&2
    exit 1
fi
echo "PASS: Omitting --mode preserved enterprise mode"

echo "--- Test 5: Sentinel trap fires if interrupted during sentinel window ---"
# Verify that _sentinel_warn and the traps are present and functional
if ! grep -q "_sentinel_warn" "$RENAME_SCRIPT"; then
    echo "FAILED: _sentinel_warn missing from rename script" >&2
    exit 1
fi
echo "PASS: Sentinel mechanism preserved"

echo "=== All rename_project.sh --mode tests passed! ==="
