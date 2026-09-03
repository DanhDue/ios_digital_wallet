---
id: "task_16_ios_acceptance_test"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["testing", "acceptance", "template"]
order: "a16"
---

# Task 16: Acceptance test end-to-end

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Final acceptance gate that validates the complete template against the Definition of Done for the epic. Run on a fresh `git worktree` to simulate a developer cloning the template.

**Acceptance test sequence**:

```bash
# 1. Create a clean worktree simulating a fresh clone
git worktree add .worktrees/acceptance_test

# 2. Rename the project
cd .worktrees/acceptance_test
./scripts/rename_project.sh AcmeWallet com.acme.wallet

# 3. Generate a new Feature using the Mason brick
mason make ios_mvi_feature --name Payments --has_network true

# 4. Follow the post_gen checklist (add to Xcode, register RouteProvider)
# (manual step — documented in checklist output)

# 5. Build and test
xcodebuild test \
  -project AcmeWallet.xcodeproj \
  -scheme AcmeWallet \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO

# 6. Quality checks
swiftlint --config quality/.swiftlint.yml --strict
swiftformat --config quality/.swiftformat . --lint
bash scripts/check_module_boundaries.sh

# 7. Cleanup
cd ../..
git worktree remove .worktrees/acceptance_test
```

**Pass criteria** (ALL must be true):
- [ ] `rename_project.sh` completes with exit 0; no `iOSDigitalWallet` string remains in source.
- [ ] `mason make ios_mvi_feature --name Payments` generates correct scaffold.
- [ ] `xcodebuild test` exits 0; all unit tests pass.
- [ ] `swiftlint --strict` exits 0.
- [ ] `swiftformat --lint` exits 0.
- [ ] `check_module_boundaries.sh` exits 0.
- [ ] App launches in Simulator: 3 tabs visible, Settings tab shows real settings screen, Scanner tab shows stub, Home tab shows stub.
- [ ] `Sources/Core/Package.swift` still references `Core` (not `AcmeWallet`) — infra namespace unchanged.
- [ ] No `.devtool/epic/` or `.devtool/features/` files reference the renamed project name (they stay as template docs).

## Relevant Files & Context Pointers

- All files in the repo — this is an integration test of the entire template
- `scripts/rename_project.sh` (Task 14)
- `bricks/ios_mvi_feature/` (Tasks 3 + 13)
- `.github/workflows/ci.yml` (Task 2) — run CI on acceptance branch
- Reference: Android `task_16_e2e_acceptance_validation.md` (mirror test sequence)
- Reference: flutter_super_app_template Phase 2 acceptance criteria

## Design Rationale

TDD adaptation: this is an acceptance/integration test — no unit test code. The test sequence IS the TDD checklist. Each step is a verifiable assertion.

Running on a git worktree (not a separate clone) allows using the repo's own scripts without setup overhead, while still simulating a "clean slate" for the renamed project.

The manual step (following `post_gen.dart` checklist) is intentional — it validates that the checklist is clear enough for a developer to follow without errors.

## TDD Checklist

TDD adapted — acceptance/integration test sequence.

- [ ] **SETUP**: `git worktree add .worktrees/acceptance_test` from `main` branch.
- [ ] **RENAME**: `./scripts/rename_project.sh AcmeWallet com.acme.wallet` → exits 0.
- [ ] **VERIFY RENAME**: `grep -r "iOSDigitalWallet" --include="*.swift" --include="*.xcodeproj" .worktrees/acceptance_test/` → zero results.
- [ ] **BRICK**: `mason make ios_mvi_feature --name Payments --has_network true` → generates correct files; checklist printed.
- [ ] **FOLLOW CHECKLIST**: Add `Features/Payments/` to Xcode + register `PaymentsRouteProvider` in `AcmeWalletApp.swift`.
- [ ] **BUILD+TEST**: `xcodebuild test ... CODE_SIGNING_ALLOWED=NO` → exits 0.
- [ ] **QUALITY**: SwiftLint strict + SwiftFormat lint + boundary check → all exits 0.
- [ ] **SIMULATOR**: App launches, 3 tabs render correctly.
- [ ] **INFRA UNCHANGED**: `cat Sources/Core/Package.swift | grep "name: \"Core\""` → found.
- [ ] **CLEANUP**: `git worktree remove .worktrees/acceptance_test`.

## Definition of Done

ALL 9 pass criteria above are true. Epic `ios_super_app_template` status updated to `done`.

Document acceptance test results in a brief note appended to `.devtool/epic/ios_super_app_template/ios_super_app_template.en.md` — include date, Xcode version, iOS Simulator version used.

## Dependencies & Blockers

- Blocked by [Task 13](task_13_ios_mason_brick_complete.md), [Task 14](task_14_ios_rename_script.md), [Task 15](task_15_ios_template_cleanup.md).
- Not blocked by any other task once those three are done.

## References & Rollback

- Source spec §14 (Lộ trình Phase 3 acceptance test).
- Rollback: `git worktree remove .worktrees/acceptance_test`. No changes committed to `main` by this task (worktree is isolated).
