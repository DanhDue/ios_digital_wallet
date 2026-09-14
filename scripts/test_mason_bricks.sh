#!/usr/bin/env bash
# scripts/test_mason_bricks.sh
# Test harness for mason bricks: ios_native_plugin & ios_add_native_ui
# Covering BDD scenario S20.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/test_mason_bricks.XXXXXX")
trap 'rm -rf "$TEST_TMPDIR"' EXIT

echo "=== Running test_mason_bricks.sh in $TEST_TMPDIR ==="

# Check mason is available
if ! command -v mason >/dev/null 2>&1; then
    echo "ERROR: mason CLI is not installed or not in PATH."
    exit 1
fi

# 1. Verify mason.yaml registration
echo "[TEST 1] Verifying mason.yaml registers ios_native_plugin and ios_add_native_ui..."
if ! grep -q "ios_native_plugin:" "$REPO_ROOT/mason.yaml"; then
    echo "FAILED: ios_native_plugin is not registered in mason.yaml"
    exit 1
fi
if ! grep -q "ios_add_native_ui:" "$REPO_ROOT/mason.yaml"; then
    echo "FAILED: ios_add_native_ui is not registered in mason.yaml"
    exit 1
fi

# Run mason get in repo root
(cd "$REPO_ROOT" && mason get)

# Expected file layouts according to pac_native_plugin contract
EXPECTED_WITH_UI=(
    "Package.swift"
    "Sources/biometric_auth/BiometricAuthPlugin.swift"
    "Sources/biometric_auth/BiometricAuthContainer.swift"
    "Sources/biometric_auth/Platform/BiometricAuthPlatformViewFactory.swift"
    "Sources/biometric_auth/Data/BiometricAuthDataSource.swift"
    "Sources/biometric_auth/Domain/BiometricAuthRepository.swift"
    "Sources/biometric_auth/Presentation/MviViewModel.swift"
    "Sources/biometric_auth/Presentation/BiometricAuthAction.swift"
    "Sources/biometric_auth/Presentation/BiometricAuthState.swift"
    "Sources/biometric_auth/Presentation/BiometricAuthEvent.swift"
    "Sources/biometric_auth/Presentation/BiometricAuthViewModel.swift"
    "Sources/biometric_auth/Presentation/BiometricAuthView.swift"
    "Sources/biometric_auth/Presentation/BiometricAuthPlatformView.swift"
    "Tests/biometric_authTests/BiometricAuthContainerTests.swift"
)

EXPECTED_HEADLESS=(
    "Package.swift"
    "Sources/biometric_auth/BiometricAuthPlugin.swift"
    "Sources/biometric_auth/BiometricAuthContainer.swift"
    "Sources/biometric_auth/Messages.g.swift"
    "Sources/biometric_auth/Platform/BiometricAuthHostApiImpl.swift"
    "Sources/biometric_auth/Data/BiometricAuthDataSource.swift"
    "Sources/biometric_auth/Domain/BiometricAuthRepository.swift"
    "Tests/biometric_authTests/BiometricAuthContainerTests.swift"
)

# 2. Test Combination 1: Fresh With-UI plugin
echo "[TEST 2] Testing ios_native_plugin --has_ui true..."
C1_DIR="$TEST_TMPDIR/c1"
mkdir -p "$C1_DIR"
(cd "$REPO_ROOT" && mason make ios_native_plugin --name biometric_auth --has_ui true -o "$C1_DIR")

TARGET_C1="$C1_DIR/biometric_auth"
if [ ! -d "$TARGET_C1" ]; then
    echo "FAILED: $TARGET_C1 directory was not emitted"
    exit 1
fi

for rel_path in "${EXPECTED_WITH_UI[@]}"; do
    if [ ! -f "$TARGET_C1/$rel_path" ]; then
        echo "FAILED: Expected file $rel_path missing in with-UI output"
        exit 1
    fi
done

if [ -f "$TARGET_C1/Sources/biometric_auth/Messages.g.swift" ]; then
    echo "FAILED: Messages.g.swift should not be present in with-UI output"
    exit 1
fi
if [ -f "$TARGET_C1/Sources/biometric_auth/Platform/BiometricAuthHostApiImpl.swift" ]; then
    echo "FAILED: BiometricAuthHostApiImpl.swift should not be present in with-UI output"
    exit 1
fi

# Verify Container uses SharedContainer and FactoryKit 3.3.2
if ! grep -q "SharedContainer" "$TARGET_C1/Sources/biometric_auth/BiometricAuthContainer.swift"; then
    echo "FAILED: BiometricAuthContainer does not subclass SharedContainer"
    exit 1
fi
if ! grep -q "3.3.2" "$TARGET_C1/Package.swift"; then
    echo "FAILED: Package.swift does not pin Factory exact 3.3.2"
    exit 1
fi

echo "  Checking SwiftFormat and SwiftLint on emitted with-UI plugin..."
(cd "$REPO_ROOT" && mise exec -- swiftformat "$TARGET_C1" --config quality/.swiftformat --lint)
(cd "$REPO_ROOT" && mise exec -- swiftlint lint "$TARGET_C1" --strict --config quality/.swiftlint.yml)

# 3. Test Combination 2: Fresh Headless plugin
echo "[TEST 3] Testing ios_native_plugin --has_ui false..."
C2_DIR="$TEST_TMPDIR/c2"
mkdir -p "$C2_DIR"
(cd "$REPO_ROOT" && mason make ios_native_plugin --name biometric_auth --has_ui false -o "$C2_DIR")

TARGET_C2="$C2_DIR/biometric_auth"
if [ ! -d "$TARGET_C2" ]; then
    echo "FAILED: $TARGET_C2 directory was not emitted"
    exit 1
fi

for rel_path in "${EXPECTED_HEADLESS[@]}"; do
    if [ ! -f "$TARGET_C2/$rel_path" ]; then
        echo "FAILED: Expected file $rel_path missing in headless output"
        exit 1
    fi
done

if [ -d "$TARGET_C2/Sources/biometric_auth/Presentation" ]; then
    echo "FAILED: Presentation/ directory should not be present in headless output"
    exit 1
fi
if [ -f "$TARGET_C2/Sources/biometric_auth/Platform/BiometricAuthPlatformViewFactory.swift" ]; then
    echo "FAILED: PlatformViewFactory should not be present in headless output"
    exit 1
fi

echo "  Checking SwiftFormat and SwiftLint on emitted headless plugin..."
(cd "$REPO_ROOT" && mise exec -- swiftformat "$TARGET_C2" --config quality/.swiftformat --lint)
(cd "$REPO_ROOT" && mise exec -- swiftlint lint "$TARGET_C2" --strict --config quality/.swiftlint.yml)

# 4. Test Combination 3: Upgrade headless plugin with ios_add_native_ui
echo "[TEST 4] Testing ios_add_native_ui upgrade from headless..."
C3_DIR="$TEST_TMPDIR/c3"
mkdir -p "$C3_DIR"
(cd "$REPO_ROOT" && mason make ios_native_plugin --name biometric_auth --has_ui false -o "$C3_DIR")

TARGET_C3="$C3_DIR/biometric_auth"
ORIG_CONTAINER_HASH=$(md5 -q "$TARGET_C3/Sources/biometric_auth/BiometricAuthContainer.swift")

(cd "$REPO_ROOT" && mason make ios_add_native_ui --name biometric_auth -o "$C3_DIR")

# Verify Presentation and PlatformViewFactory were added
if [ ! -d "$TARGET_C3/Sources/biometric_auth/Presentation" ]; then
    echo "FAILED: Presentation directory not added by ios_add_native_ui"
    exit 1
fi
if [ ! -f "$TARGET_C3/Sources/biometric_auth/Platform/BiometricAuthPlatformViewFactory.swift" ]; then
    echo "FAILED: BiometricAuthPlatformViewFactory.swift not added by ios_add_native_ui"
    exit 1
fi
if [ ! -f "$TARGET_C3/Sources/biometric_auth/Presentation/BiometricAuthView.swift" ]; then
    echo "FAILED: BiometricAuthView.swift not added by ios_add_native_ui"
    exit 1
fi

# Verify container was NOT overwritten
NEW_CONTAINER_HASH=$(md5 -q "$TARGET_C3/Sources/biometric_auth/BiometricAuthContainer.swift")
if [ "$ORIG_CONTAINER_HASH" != "$NEW_CONTAINER_HASH" ]; then
    echo "FAILED: BiometricAuthContainer.swift was modified during upgrade"
    exit 1
fi

# Verify plugin was patched to register PlatformViewFactory
if ! grep -q "BiometricAuthPlatformViewFactory" "$TARGET_C3/Sources/biometric_auth/BiometricAuthPlugin.swift"; then
    echo "FAILED: BiometricAuthPlugin was not patched with BiometricAuthPlatformViewFactory"
    exit 1
fi

echo "  Checking SwiftFormat and SwiftLint on upgraded plugin..."
(cd "$REPO_ROOT" && mise exec -- swiftformat "$TARGET_C3" --config quality/.swiftformat --lint)
(cd "$REPO_ROOT" && mise exec -- swiftlint lint "$TARGET_C3" --strict --config quality/.swiftlint.yml)

# 5. Test Combination 4: Re-running upgrade on already-UI plugin
echo "[TEST 5] Testing re-running ios_add_native_ui on already-UI plugin..."
RE_RUN_OUTPUT=$(cd "$REPO_ROOT" && mason make ios_add_native_ui --name biometric_auth -o "$C3_DIR" 2>&1 || true)
if ! echo "$RE_RUN_OUTPUT" | grep -qi "already has native UI"; then
    echo "FAILED: Re-running upgrade brick did not warn about existing UI. Output: $RE_RUN_OUTPUT"
    exit 1
fi

echo "=== All test_mason_bricks.sh checks passed! ==="
