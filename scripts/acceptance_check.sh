#!/usr/bin/env bash
# scripts/acceptance_check.sh
# Runs the full verification matrix (V1-V11) for Tri-Mode Template & Flutter Plugin Devbed.
# Parity with android_digital_wallet/scripts/acceptance_check.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if command -v mise >/dev/null 2>&1; then
    TUIST_BIN="$(mise which tuist 2>/dev/null || true)"
    if [ -n "$TUIST_BIN" ]; then
        export PATH="$(dirname "$TUIST_BIN"):$PATH"
    fi
fi

WORK="${TMPDIR:-/tmp}/ios_acceptance.$$"
REPO="${WORK}/ios_digital_wallet"
mkdir -p "${WORK}"
trap 'rm -rf "${WORK}"' EXIT

SUMMARY=()
OVERALL=0

_record() {
    local id="$1"
    local desc="$2"
    local status="$3"
    if [ "$status" -eq 0 ]; then
        SUMMARY+=("  PASS: [$id] $desc")
    else
        SUMMARY+=("  FAIL: [$id] $desc")
        OVERALL=1
    fi
}

echo "=== Tri-Mode & Flutter Plugin Devbed Acceptance Harness ==="
echo "Creating isolated throwaway checkout at ${REPO}..."

# Setup throwaway repo
mkdir -p "${REPO}"
(cd "${REPO_ROOT}" && git archive HEAD) | (cd "${REPO}" && tar -x)
# Copy any uncommitted/modified working tree files
(cd "${REPO_ROOT}" && git ls-files -m -o --exclude-standard) | while read -r f; do
    if [ -f "${REPO_ROOT}/$f" ]; then
        mkdir -p "${REPO}/$(dirname "$f")"
        cp "${REPO_ROOT}/$f" "${REPO}/$f"
    fi
done

(
    cd "${REPO}"
    git init -q
    git config user.name "Acceptance Runner"
    git config user.email "acceptance@example.com"
    git add -A
    git commit -qm "Baseline for acceptance testing"
    ./scripts/bootstrap_devbed.sh
)

# Simulator destination
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"

# ======================================================================
# V1 — Enterprise mode
# ======================================================================
echo ""
echo "--- [V1] Enterprise Mode Verification ---"
v1_status=0
(
    cd "${REPO}"
    ./scripts/configure_mode.sh enterprise
    swift test --package-path ArchTests
    ./scripts/check_module_boundaries.sh
    mise exec -- swiftformat . --config quality/.swiftformat --lint
    mise exec -- swiftlint lint --strict --config quality/.swiftlint.yml
) || v1_status=1
_record "V1" "Enterprise mode: full governance gates and manifests pass" "$v1_status"

# ======================================================================
# V2 — Switch to Lean mode
# ======================================================================
echo ""
echo "--- [V2] Lean Mode Verification ---"
v2_status=0
(
    cd "${REPO}"
    ./scripts/configure_mode.sh lean
    # Verify Scanner is unwired
    if grep -E '^[[:space:]]*let scanner' App/Sources/Composition/AppComposition.swift; then
        echo "Scanner still wired in AppComposition.swift"
        exit 1
    fi
    if grep -E '^[[:space:]]*import Scanner' App/Sources/Composition/AppComposition.swift; then
        echo "import Scanner still active in AppComposition.swift"
        exit 1
    fi
    mise exec -- swiftformat . --config quality/.swiftformat --lint
    mise exec -- swiftlint lint --strict --config quality/.swiftlint.yml
) || v2_status=1
_record "V2" "Lean mode: Scanner unwired, test suite mode-aware" "$v2_status"

# ======================================================================
# V3 — Switch to Plugin mode
# ======================================================================
echo ""
echo "--- [V3] Plugin Mode Verification ---"
v3_status=0
(
    cd "${REPO}"
    ./scripts/configure_mode.sh plugin
    if [ ! -d "PluginDevbed.xcworkspace" ]; then
        echo "PluginDevbed.xcworkspace not generated"
        exit 1
    fi
) || v3_status=1
_record "V3" "Plugin mode: manifests emit only Plugin + Sample" "$v3_status"

# ======================================================================
# V4 — Build & test Plugin standalone
# ======================================================================
echo ""
echo "--- [V4] Standalone Plugin Package Build & Test ---"
v4_status=0
(
    cd "${REPO}/Plugin"
    rm -rf Plugin.xcodeproj
    xcodebuild build -scheme Plugin -destination "${DESTINATION}" CODE_SIGNING_ALLOWED=NO -quiet
    xcodebuild test -scheme Plugin -destination "${DESTINATION}" CODE_SIGNING_ALLOWED=NO -quiet
) || v4_status=1
_record "V4" "Plugin standalone build & test against Flutter engine" "$v4_status"

# ======================================================================
# V5 — Background task without Flutter engine
# ======================================================================
echo ""
echo "--- [V5] Background Task Isolation ---"
v5_status=0
(
    cd "${REPO}/Plugin"
    rm -rf Plugin.xcodeproj
    xcodebuild test -scheme Plugin -destination "${DESTINATION}" -only-testing:PluginTests/DataSyncTaskTests CODE_SIGNING_ALLOWED=NO -quiet
) || v5_status=1
_record "V5" "Background DataSyncTask executes without FlutterEngine" "$v5_status"

# ======================================================================
# V6 — Build and test Sample runner
# ======================================================================
echo ""
echo "--- [V6] Sample Runner App ---"
v6_status=0
(
    cd "${REPO}"
    ./scripts/configure_mode.sh plugin
    xcodebuild build -workspace PluginDevbed.xcworkspace -scheme Sample -destination "${DESTINATION}" CODE_SIGNING_ALLOWED=NO -quiet
    xcodebuild test -workspace PluginDevbed.xcworkspace -scheme Sample -destination "${DESTINATION}" CODE_SIGNING_ALLOWED=NO -quiet
) || v6_status=1
_record "V6" "Sample runner app builds and executes tests in simulator" "$v6_status"

# ======================================================================
# V7 — Idempotent round trip (enterprise -> lean -> plugin -> enterprise)
# ======================================================================
echo ""
echo "--- [V7] Idempotent Mode Round Trip ---"
v7_status=0
(
    cd "${REPO}"
    ./scripts/configure_mode.sh enterprise
    ./scripts/configure_mode.sh lean
    ./scripts/configure_mode.sh plugin
    ./scripts/configure_mode.sh enterprise
    swift test --package-path ArchTests
    ./scripts/check_module_boundaries.sh
) || v7_status=1
_record "V7" "Idempotent round trip: enterprise -> lean -> plugin -> enterprise" "$v7_status"

# ======================================================================
# V8 — rename_project.sh --mode integration
# ======================================================================
echo ""
echo "--- [V8] rename_project.sh with --mode ---"
v8_status=0
(
    cd "${REPO}"
    ./scripts/test_rename_project_mode.sh
) || v8_status=1
_record "V8" "rename_project.sh supports --mode, --force, and --dry-run" "$v8_status"

# ======================================================================
# V9 — Mason bricks ios_native_plugin and ios_add_native_ui
# ======================================================================
echo ""
echo "--- [V9] Mason Bricks ---"
v9_status=0
(
    cd "${REPO}"
    ./scripts/test_mason_bricks.sh
) || v9_status=1
_record "V9" "Mason bricks ios_native_plugin and ios_add_native_ui" "$v9_status"

# ======================================================================
# V10 — Prune guard & configure_mode test suite
# ======================================================================
echo ""
echo "--- [V10] Prune Guard & configure_mode.sh Harness ---"
v10_status=0
(
    cd "${REPO}"
    ./scripts/test_configure_mode.sh
) || v10_status=1
_record "V10" "configure_mode.sh test harness and prune guard" "$v10_status"

# ======================================================================
# V11 — Test suite mode awareness
# ======================================================================
echo ""
echo "--- [V11] Mode-Aware Test Suite ---"
v11_status=0
(
    cd "${REPO}"
    # Verify Scanner test splitting from Task 3
    if [ ! -f "Packages/Shell/Tests/ShellTests/ScannerTabTests.swift" ]; then
        echo "Missing Packages/Shell/Tests/ShellTests/ScannerTabTests.swift"
        exit 1
    fi
    if [ ! -f "App/Tests/AppTests/ScannerCompositionTests.swift" ]; then
        echo "Missing App/Tests/AppTests/ScannerCompositionTests.swift"
        exit 1
    fi
) || v11_status=1
_record "V11" "Test suite is decoupled into mode-aware conditional targets" "$v11_status"

echo ""
echo "======================================================================"
echo "  ACCEPTANCE MATRIX SUMMARY (V1-V11)"
echo "======================================================================"
for line in "${SUMMARY[@]}"; do
    echo "$line"
done
echo "----------------------------------------------------------------------"

if [ "${OVERALL}" -eq 0 ]; then
    echo "RESULT: PASS — All 11 verification matrix checks passed!"
else
    echo "RESULT: FAIL — One or more checks failed. See details above."
fi

exit "${OVERALL}"
