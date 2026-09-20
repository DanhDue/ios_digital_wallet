#!/usr/bin/env bash
set -euo pipefail

echo "================================================================="
echo "🛡️  Checking Release Isolation (BDD UC-5.3)"
echo "================================================================="

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# 1. Build the Release configuration
echo "Building iOSDigitalWallet (Release configuration)..."
xcodebuild build \
  -workspace iOSDigitalWallet.xcworkspace \
  -scheme iOSDigitalWallet \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  -quiet

BUILD_OUTPUT=$(xcodebuild \
  -workspace iOSDigitalWallet.xcworkspace \
  -scheme iOSDigitalWallet \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -showBuildSettings)

TARGET_BUILD_DIR=$(echo "$BUILD_OUTPUT" | grep -E '^\s*TARGET_BUILD_DIR =' | head -n 1 | awk '{print $3}')
EXECUTABLE_PATH=$(echo "$BUILD_OUTPUT" | grep -E '^\s*EXECUTABLE_PATH =' | head -n 1 | awk '{print $3}')

if [ -z "$TARGET_BUILD_DIR" ] || [ -z "$EXECUTABLE_PATH" ]; then
  echo "❌ Error: Could not determine build artifacts directory."
  exit 1
fi

BINARY_PATH="$TARGET_BUILD_DIR/$EXECUTABLE_PATH"
APP_BUNDLE_PATH="$(dirname "$BINARY_PATH")"

if [ ! -f "$BINARY_PATH" ]; then
  echo "❌ Error: Binary not found at $BINARY_PATH"
  exit 1
fi

echo "Inspecting binary: $BINARY_PATH"

# 2. Check that PulseUI.framework is not bundled
FRAMEWORKS_DIR="$APP_BUNDLE_PATH/Frameworks"
if [ -d "$FRAMEWORKS_DIR/PulseUI.framework" ]; then
  echo "❌ Violation: PulseUI.framework was packaged into Release app bundle!"
  exit 1
fi

# 3. Check binary symbols via nm
NM_OUTPUT=$(nm -g "$BINARY_PATH" 2>/dev/null || true)

PROHIBITED_SYMBOLS=(
  "PulseUI"
  "ShakeGesture"
  "deviceDidShakeNotification"
  "LoggingDiagnosticsView"
  "LoggingDiagnosticsViewModel"
  "LeakSentinel"
  "LeakDemoView"
  "LeakDemoViewModel"
)

VIOLATIONS=0

for SYMBOL in "${PROHIBITED_SYMBOLS[@]}"; do
  if echo "$NM_OUTPUT" | grep -q "$SYMBOL"; then
    echo "❌ Symbol violation: Found prohibited symbol '$SYMBOL' in Release binary symbols!"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

# 4. Check binary string table
STRINGS_OUTPUT=$(strings "$BINARY_PATH" 2>/dev/null || true)
for SYMBOL in "${PROHIBITED_SYMBOLS[@]}"; do
  if echo "$STRINGS_OUTPUT" | grep -q "$SYMBOL"; then
    echo "❌ String violation: Found prohibited string '$SYMBOL' in Release binary strings!"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

if [ "$VIOLATIONS" -gt 0 ]; then
  echo "❌ Release isolation FAILED with $VIOLATIONS violation(s)."
  exit 1
fi

echo "✅ Release isolation verified: No PulseUI, ShakeGesture, or developer diagnostics found in Release binary or frameworks."
exit 0
