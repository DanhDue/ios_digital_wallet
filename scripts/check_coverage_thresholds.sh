#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "================================================================="
echo "📊 Checking Coverage Thresholds (HLD §5.6 / Gate 4)"
echo "================================================================="

INJECT_GAP=false
if [ "${1:-}" = "--inject-gap" ]; then
    INJECT_GAP=true
    echo "⚠️  Simulation mode: --inject-gap enabled (testing gate failure)"
fi

python3 - <<EOF
import json
import os
import subprocess
import sys

root_dir = "$ROOT_DIR"
inject_gap = "$INJECT_GAP" == "true"

def find_test_artifacts(package_path, test_binary_name):
    build_dir = os.path.join(root_dir, package_path, ".build")
    if not os.path.exists(build_dir):
        return None, None
    
    found_bin = None
    found_prof = None
    for root, dirs, files in os.walk(build_dir):
        if ".dSYM" in root:
            continue
        if test_binary_name in files and "Contents/MacOS" in root:
            found_bin = os.path.join(root, test_binary_name)
        if "default.profdata" in files and "codecov" in root:
            found_prof = os.path.join(root, "default.profdata")
    
    if found_bin and found_prof:
        if os.path.getmtime(found_bin) > os.path.getmtime(found_prof):
            return None, None
    return found_bin, found_prof

def run_tests_with_coverage(package_path):
    print(f"Running tests with coverage for {package_path}...")
    cmd = ["swift", "test", "--package-path", package_path, "--enable-code-coverage"]
    subprocess.run(cmd, cwd=root_dir, check=True)

# 1. Locate or generate artifacts for D3NexusLogging
logging_bin, logging_prof = find_test_artifacts("Packages/D3NexusLogging", "D3NexusLoggingPackageTests")
if not logging_bin or not logging_prof:
    run_tests_with_coverage("Packages/D3NexusLogging")
    logging_bin, logging_prof = find_test_artifacts("Packages/D3NexusLogging", "D3NexusLoggingPackageTests")

# 2. Locate or generate artifacts for Settings
settings_bin, settings_prof = find_test_artifacts("Features/Settings", "SettingsPackageTests")
if not settings_bin or not settings_prof:
    run_tests_with_coverage("Features/Settings")
    settings_bin, settings_prof = find_test_artifacts("Features/Settings", "SettingsPackageTests")

if not logging_bin or not logging_prof:
    print("❌ Error: Could not locate D3NexusLogging test binary or profdata.")
    sys.exit(1)

if not settings_bin or not settings_prof:
    print("❌ Error: Could not locate Settings test binary or profdata.")
    sys.exit(1)

def get_coverage(binary, profdata, sources):
    cmd = [
        "xcrun", "llvm-cov", "export", binary,
        f"-instr-profile={profdata}",
        "-summary-only"
    ]
    for s in sources:
        cmd.extend(["-sources", os.path.join(root_dir, s)])
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return None, 0, 0, []
    data = json.loads(res.stdout)
    totals = data["data"][0]["totals"]["lines"]
    count = totals["count"]
    covered = totals["covered"]
    pct = (covered / count * 100) if count > 0 else 0
    
    file_details = []
    for f in data["data"][0].get("files", []):
        f_lines = f["summary"]["lines"]
        f_cnt = f_lines["count"]
        f_cov = f_lines["covered"]
        f_pct = (f_cov / f_cnt * 100) if f_cnt > 0 else 0
        file_details.append((os.path.basename(f["filename"]), f_pct, f_cnt, f_cov))
    
    return pct, count, covered, file_details

checks = [
    ("Redaction/** (Security)", logging_bin, logging_prof, ["Packages/D3NexusLogging/Sources/D3NexusLogging/Redaction"], 100.0),
    ("Trace/** (ID & Tree)", logging_bin, logging_prof, ["Packages/D3NexusLogging/Sources/D3NexusLogging/Trace"], 100.0),
    ("Manager/** & Logger/**", logging_bin, logging_prof, [
        "Packages/D3NexusLogging/Sources/D3NexusLogging/Manager",
        "Packages/D3NexusLogging/Sources/D3NexusLogging/Logger"
    ], 90.0),
    ("Appender/** & Bridge/**", logging_bin, logging_prof, [
        "Packages/D3NexusLogging/Sources/D3NexusLogging/Appender",
        "Packages/D3NexusLogging/Sources/D3NexusLogging/Bridge"
    ], 85.0),
    ("Diagnostics/** (Sentinel)", logging_bin, logging_prof, ["Packages/D3NexusLogging/Sources/D3NexusLogging/Diagnostics"], 90.0),
    ("Diagnostics ViewModels", settings_bin, settings_prof, [
        "Features/Settings/Sources/Settings/Presentation/Diagnostics/LeakDemo/LeakDemoViewModel.swift",
        "Features/Settings/Sources/Settings/Presentation/Diagnostics/LoggingDiagnosticsViewModel.swift"
    ], 80.0),
]

print(f"{'Area / Scope':<32} {'Actual':<9} {'Required':<10} {'Lines':<14} {'Verdict'}")
print("-" * 75)

violations = 0

for name, binary, prof, sources, threshold in checks:
    pct, count, covered, files = get_coverage(binary, prof, sources)
    
    # Simulate gap if requested
    if inject_gap and "Redaction" in name:
        pct = 95.0
        covered = int(count * 0.95)

    if pct is None:
        print(f"{name:<32} ERROR: Failed to compute coverage")
        violations += 1
        continue
    
    is_pass = pct >= threshold
    verdict = "✅ PASS" if is_pass else "❌ FAIL"
    if not is_pass:
        violations += 1
    
    print(f"{name:<32} {pct:6.2f}%   {threshold:5.1f}%     {covered}/{count:<9} {verdict}")

print("-" * 75)

if violations > 0:
    print(f"❌ Coverage check FAILED: {violations} area(s) fell below threshold.")
    sys.exit(1)

print("✅ All HLD §5.6 coverage thresholds satisfied!")
EOF
