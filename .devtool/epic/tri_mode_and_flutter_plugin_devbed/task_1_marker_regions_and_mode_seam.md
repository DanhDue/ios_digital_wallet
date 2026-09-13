---
id: "task_1_marker_regions_and_mode_seam"
status: "todo"
priority: "high"
assignee: null
epic: "tri_mode_and_flutter_plugin_devbed"
dueDate: null
created: "2026-09-13T21:29:15Z"
modified: "2026-09-13T21:29:15Z"
completedAt: null
labels: ["architecture", "tooling", "refactor"]
order: "a1"
---

# Task 1: Marker Regions & ActiveMode Seam

Epic: [tri_mode_and_flutter_plugin_devbed](tri_mode_and_flutter_plugin_devbed.en.md)

## Requirement Analysis

Every later task depends on a mode seam existing. This task installs it **without changing any
observable behaviour**: `activeMode` defaults to `.enterprise`, and the full governance gate must
still pass exactly as it does today.

Two mechanisms, chosen per file type (HLD §4.6):

1. **Tuist manifests** branch on a generated constant in
   `Tuist/ProjectDescriptionHelpers/ActiveMode.swift`. Manifests are real Swift, so branching is
   idempotent by construction and cannot produce a syntax error — which matters most in Mode 3,
   where the whole target list changes, not just a dependency list.
2. **App and Shell sources** get marker-region comments, exactly as the Android template does,
   because these files compile into the binary and must not carry dead branches.

Four marker regions are missing and must be added. The existing four
(`tuist:packages`, `tuist:app-deps`, `app:feature-imports`, `app:route-providers`) must be kept
**verbatim** — Mason bricks edit them.

## Relevant Files & Context Pointers

- `Tuist/ProjectDescriptionHelpers/ActiveMode.swift` — **new**, the mode constant.
- `Tuist/ProjectDescriptionHelpers/Module.swift` — shared target factory; do not redefine
  deployment targets here.
- `Tuist/Package.swift` — has `tuist:packages:begin/end`; wrap, do not replace.
- `Project.swift` — has `tuist:app-deps:begin/end`; branch the `targets:` array on `activeMode`.
- `Workspace.swift` — branch the `projects:` array on `activeMode`.
- `App/Sources/Composition/AppComposition.swift` — has `app:feature-imports` and
  `app:route-providers`.
- `App/Sources/Composition/DeepLinkComposition.swift` — add `app:tab-resolver-scanner:begin/end`
  around the `ScannerRoot` case in `ShellTabResolver.placement(for:)`.
- `Packages/Shell/Sources/Shell/ShellView.swift` — add `shell:scanner-tab:begin/end` and
  `shell:settings-tab:begin/end`.
- `Packages/Shell/Sources/Shell/ShellConfig.swift` — add `shell:config-defaults:begin/end` around
  the `init(tabCount: Int = 3, initialTab: Int = 2)` defaults.

## Design Rationale

- **Why a constant, not regex, for manifests.** Regex-commenting an entire `Target(...)` literal
  is the single operation most likely to leave an unparseable manifest. A constant makes a broken
  switch structurally impossible.
- **Why marker regions still, for app sources.** A compiled binary must not ship dead branches, and
  this is the mechanism the Android template already proved.
- **Why `ShellConfig` cannot be a pure runtime flag.** `ShellView` does not import the `Scanner`
  package — it names only `AppRoutes.ScannerRoot()` from `Platform` — so it compiles fine in lean
  mode. But the tab would still render and resolve to nothing. The region must be commented out.
- **Applicable skills**: `ios-ui-audit` (SwiftUI body re-evaluation when the tab list changes),
  Tuist (`tuist generate`), `ArchTests`.

### BDD SCENARIOS

```gherkin
Scenario: The seam is installed with no behavioural change  [Tier C - Integration]
  Given the repository is on develop with a clean git tree
  When ActiveMode.swift is added with activeMode == .enterprise
  And the four missing marker regions are added
  Then "tuist install && tuist generate --no-open" succeeds
  And "xcodebuild build" succeeds
  And "swift test --package-path ArchTests" passes all rules K1-K10
  And "bash scripts/check_module_boundaries.sh" passes
  And the app still renders three tabs with Settings selected on cold start

Scenario: Manifests branch on the mode constant  [Tier A - Unit]
  Given ActiveMode.swift declares activeMode
  When activeMode is .enterprise
  Then Tuist/Package.swift includes the Scanner and Settings package paths
  And Project.swift declares the app target with all external dependencies
  When activeMode is .lean
  Then the Scanner package path and external dependency are absent
  When activeMode is .plugin
  Then only the Plugin package and the Sample app target are declared

Scenario: Existing marker regions are preserved byte-for-byte  [Tier A - Unit]
  Given Mason bricks insert lines into tuist:packages and tuist:app-deps
  When this task wraps those regions in an activeMode branch
  Then the begin and end marker comments are unchanged
  And a brick run still inserts its line inside the region correctly

Scenario: Marker regions are lint-clean  [Tier C - Integration]
  Given the four new marker regions are in place
  When swiftlint --strict and swiftformat --lint run from the repo root
  Then both report zero violations
```

## Test & Verification Checklist

- [ ] **RED**: This task adds no new runtime behaviour. Adaptation: capture the current output of
      `xcodebuild build`, `swift test --package-path ArchTests`, `check_module_boundaries.sh` and
      the Shell/App test suites as the baseline to prove zero regression against.
- [ ] **GREEN**: Add `ActiveMode.swift`; branch `Tuist/Package.swift`, `Project.swift` and
      `Workspace.swift` on `activeMode`; add the four marker regions.
- [ ] **REFACTOR**: `swiftformat --config quality/.swiftformat .` then
      `swiftlint lint --strict --config quality/.swiftlint.yml`.
- [ ] **Tier B**: `bash scripts/check_module_boundaries.sh` and
      `swift test --package-path ArchTests` both pass.
- [ ] **Tier C**: `tuist install && tuist generate --no-open && xcodebuild build -workspace
      iOSDigitalWallet.xcworkspace -scheme iOSDigitalWallet -destination 'generic/platform=iOS Simulator'
      CODE_SIGNING_ALLOWED=NO`, plus the full existing test suite, all green.

## Definition of Done

- `ActiveMode.swift` exists and all three manifests branch on it.
- All eight marker regions present; the four pre-existing ones unchanged.
- Zero behavioural change: every pre-task verification command produces the same result.
- SwiftLint strict and SwiftFormat lint clean.
- Clean `git status` after the single task commit.

## Dependencies & Blockers

- Blocks [Task 2](task_2_configure_mode_script.md), [Task 3](task_3_mode_aware_test_suite.md),
  [Task 5](task_5_bootstrap_devbed_flutter_binding.md).
- Blocked by: nothing. This is the entry task.

## References & Rollback

- HLD §4.6 (mode seam), §4.4 (mode matrix).
- `AGENTS.md` — the `// tuist:*:begin/end` regions are edited by Mason bricks; keep them verbatim.
- **Rollback**: `git revert` the task commit. Nothing else depends on the seam yet, and the
  default `.enterprise` branch reproduces today's graph exactly.
