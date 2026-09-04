---
id: "task_15_ios_acceptance_e2e"
status: "done"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: "2026-09-04T04:09:56Z"
labels: ["testing", "acceptance", "template"]
order: "a15"
---

# Task 15: Acceptance test end-to-end

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: C (acceptance).** The test sequence *is* the checklist — expressed as `### End-to-End Scenarios` (Gherkin) per Source Spec §9A.

## Requirement Analysis

Final gate: validate the whole template against the epic's Definition of Done on a fresh `git worktree` simulating a clone. Verification uses `tuist generate` + `xcodebuild` + `swift test` — **never `melos`** (the `epic-implementation` skill is Flutter-flavored; Source Spec §9A / Nuồn tham chiếu overrides the target to Swift/XCTest).

Record results (date, Xcode version, iOS Simulator version) appended to `ios_super_app_template.en.md`.

## Relevant Files & Context Pointers

- Entire repo — this is an integration test of the template
- `scripts/rename_project.sh` (Task 14), `bricks/ios_*` (Task 13), `.github/workflows/ci.yml` (Task 3), `ArchTests/` (Tasks 3/9/12)
- Source Spec §14 (Phase 3 acceptance), §9A; Android `task_16_e2e_acceptance_validation.md` (parity)

## Design Rationale

Running on a worktree (not a separate clone) reuses the repo's own scripts with zero setup while still simulating a clean slate. The manual "follow the `post_gen` checklist" step is intentional — it validates the checklist is clear enough to follow without error.

**Applicable skills:** `superpowers:verification-before-completion` — do not mark done without the recorded command output.

### End-to-End Scenarios

```gherkin
Background:
  Given a fresh worktree: git worktree add .worktrees/acceptance_test main
  And mise install has resolved the pinned Tuist / SwiftLint / SwiftFormat

Scenario: rename the template
  When ./scripts/rename_project.sh AcmeWallet com.acme.wallet
  Then it exits 0
  And grep -r "iOSDigitalWallet" Project.swift Workspace.swift App/ returns nothing
  And Packages/Core/Package.swift still declares name "Core"

Scenario: generate a new feature via Mason
  When mason make ios_mvi_feature --name Payments --has_network true
  Then Packages/Features/PaymentsFeature/ exists with Data/Domain/Presentation + PaymentsRouteProvider
  And Tuist/Package.swift and Project.swift each gained one PaymentsFeature entry in their marker regions
  And the post_gen checklist was printed

Scenario: follow the checklist
  When I register PaymentsRouteProvider in App/Sources/Composition/AppComposition.swift
  Then no other file needs editing

Scenario: everything builds and tests green
  When tuist generate --no-open
  And xcodebuild test -workspace AcmeWallet.xcworkspace -scheme AcmeWallet -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' CODE_SIGNING_ALLOWED=NO
  And swift test is run for ArchTests and every Packages/* and Packages/Features/* (incl. the new PaymentsFeature)
  Then all exit 0

Scenario: quality gates green
  When swiftlint --strict --config quality/.swiftlint.yml
  And swiftformat --config quality/.swiftformat . --lint
  And bash scripts/check_module_boundaries.sh
  Then all exit 0

Scenario: ArchTests full rule set
  When swift test --package-path ArchTests
  Then K1..K9 all pass with an empty baseline and empty whitelist

Scenario: simulator smoke — 3 tabs
  When the app launches on the iPhone 16 simulator
  Then Home stub, Scanner "coming soon", and real Settings are each reachable
  And Settings is the default selected tab
  And pushing a screen in Settings, switching to Home, and back preserves the Settings stack (per-tab nav)

Scenario: event bus round-trip
  When Settings triggers a state change that publishes on AppEventBus
  Then a Shell subscriber observes it (integration test in App/Tests)

Scenario: remove the generated feature cleanly
  When mason make ios_remove_feature --name Payments
  Then Packages/Features/PaymentsFeature/ is gone
  And the marker regions no longer mention PaymentsFeature
  And tuist generate exits 0

Scenario: cleanup
  When git worktree remove .worktrees/acceptance_test
  Then nothing was committed to main by this task
```

### Adaptation note

TDD adapted: acceptance/integration. Each scenario is a verifiable assertion with recorded command output; no new production code.

## Definition of Done

- Every End-to-End Scenario passes with command output captured.
- `xcodebuild test` + all `swift test` suites + `ArchTests` (K1–K9) + SwiftLint/SwiftFormat + boundary check all exit 0 on the renamed template with a Mason-generated feature.
- Simulator smoke confirms 3 tabs, default = Settings, per-tab nav preserved.
- `mason make ios_remove_feature` cleanly reverses the generated feature.
- Results note (date, Xcode, Simulator versions) appended to `ios_super_app_template.en.md`; epic `Status` updated.

## Dependencies & Blockers

- Blocked by [Task 13](task_13_ios_mason_bricks.md), [Task 14](task_14_ios_rename_and_genericize.md).
- Not blocked by anything else once those are done.

## References & Rollback

- Source Spec §14, §9A.
- Rollback: `git worktree remove .worktrees/acceptance_test`. Nothing is committed to `main` by this task.
