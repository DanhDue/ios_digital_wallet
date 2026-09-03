---
id: "task_14_ios_rename_script"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["template", "tooling"]
order: "a14"
---

# Task 14: Implement `rename_project.sh`

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Implement `scripts/rename_project.sh` — the single entry point for a developer after cloning the template. Usage:

```bash
./scripts/rename_project.sh <NewAppName> <new.bundle.id>
# Example:
./scripts/rename_project.sh MyWallet com.mycompany.mywallet
```

**What the script must do** (in order):

1. **Validate**: check git tree is clean (`git status --porcelain` = empty); check `$1` and `$2` args provided; check no spaces in args.
2. **String replace in files**: using `LC_ALL=C sed -i ''` (BSD sed for macOS), replace:
   - `iOSDigitalWallet` → `<NewAppName>` in `.swift`, `Package.swift`, `*.xcconfig`, `*.plist`, `*.md`
   - `com.danhdue.iOSDigitalWallet` → `<new.bundle.id>` in `project.pbxproj`, `Info.plist`, `*.xcconfig`
3. **Rename filesystem directories/files**: `iOSDigitalWallet/` app folder → `<NewAppName>/`; `iOSDigitalWallet.xcodeproj/` → `<NewAppName>.xcodeproj/` (use `git mv` to preserve history).
4. **Do NOT rename**: `Sources/Core`, `Sources/Framework`, `Sources/Network`, `Sources/AppUIKit`, `Sources/Platform` — these are the "vendor namespace" infra packages, independent of project name.
5. **Verify**: run `xcodebuild build -scheme <NewAppName> CODE_SIGNING_ALLOWED=NO` → must succeed.
6. **Report**: print summary of replacements made and verification result.

## Relevant Files & Context Pointers

- `scripts/rename_project.sh` — **NEW**
- `iOSDigitalWallet.xcodeproj/project.pbxproj` — primary target for bundle ID replacement
- `iOSDigitalWallet/App/iOSDigitalWalletApp.swift` — struct name rename
- `iOSDigitalWallet/` directory — `git mv` rename
- All `Sources/*/Package.swift` — product names may contain `iOSDigitalWallet` in target references
- Reference: `scripts/rename_project.sh` in `bloc_digital_wallet` (Flutter template — adapt macOS `sed` syntax)
- Reference: Android `scripts/rename_project.sh` (android_super_app_template Task 15)
- Source spec §12 (rename script)

## Design Rationale

TDD adaptation: shell script I/O — no unit tests. Verification is a full end-to-end clone-and-rename test (covered in Task 16 acceptance test). This task's Definition of Done includes a smoke test on the current repo.

Using `git mv` (not `mv`) for directory renames preserves git history for moved files, making `git log --follow` work after rename — important for a template that developers will fork.

**NOT renaming SPM infra packages** (`Core`, `Framework`, etc.) is a deliberate decision matching `flutter_super_app_template` §5 ("vendor namespace fixed at `com.danhdue.*`"). The infra packages are framework code, not application code — their identity is independent of the project name.

## TDD Checklist

TDD adapted — shell script, verified by smoke test.

- [ ] **WRITE**: `scripts/rename_project.sh` with all 6 steps above.
- [ ] **SMOKE TEST** (on a git worktree copy, not main branch):
  1. Create worktree: `git worktree add .worktrees/rename_test`
  2. Run: `./scripts/rename_project.sh TestApp com.test.testapp`
  3. Verify: `xcodebuild build -scheme TestApp CODE_SIGNING_ALLOWED=NO` exits 0
  4. Verify: `grep -r "iOSDigitalWallet" TestApp.xcodeproj TestApp/` → zero results (no unreplaced old name)
  5. Verify: `Sources/Core/Package.swift` still contains `Core` (not `TestApp`) — infra unchanged
  6. Cleanup: `git worktree remove .worktrees/rename_test`
- [ ] **VERIFY**: `./scripts/rename_project.sh` with no args → prints usage and exits 1.
- [ ] **VERIFY**: Dirty git tree → script exits 1 with "Uncommitted changes" message.

## Definition of Done

- `scripts/rename_project.sh` exists and is executable (`chmod +x`).
- Smoke test on worktree passes: renamed app builds, no old name strings remain, infra packages unchanged.
- Script exits non-zero with helpful message on invalid input.

## Dependencies & Blockers

- Blocked by [Task 12](task_12_ios_features_and_routing.md) (full template structure must exist for rename to be meaningful).
- Blocks [Task 16](task_16_ios_acceptance_test.md) (acceptance test uses this script).

## References & Rollback

- Source spec §12 (rename script detail).
- Rollback: delete `scripts/rename_project.sh`. No other files changed.
