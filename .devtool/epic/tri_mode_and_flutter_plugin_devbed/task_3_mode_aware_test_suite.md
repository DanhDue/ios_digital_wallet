---
id: "task_3_mode_aware_test_suite"
status: "todo"
priority: "high"
assignee: null
epic: "tri_mode_and_flutter_plugin_devbed"
dueDate: null
created: "2026-09-13T21:29:15Z"
modified: "2026-09-13T21:29:15Z"
completedAt: null
labels: ["testing", "refactor", "architecture"]
order: "a3"
---

# Task 3: Make the Test Suite Mode-Aware

Epic: [tri_mode_and_flutter_plugin_devbed](tri_mode_and_flutter_plugin_devbed.en.md)

## Requirement Analysis

A gap with no Android counterpart, and the reason it exists is structural: Android's lean mode
drops a Dynamic Feature Module that owns its own tests, so nothing else breaks. On iOS the
tab-structure tests live in the **shared** `Shell` package and in `App/Tests`, and they hard-code
the enterprise shape — **51 references across 10 files** assert `Scanner` or `tabCount: 3`.

`App/Tests/AppTests/AppCompositionTests.swift:26` asserts *"exactly one provider handles
ScannerRoot"*; in lean mode there is no such provider and the assertion fails outright.

Without this task, `configure_mode.sh lean` produces a project that **builds but has a red test
suite** — worse than shipping no mode switch at all.

**Approach.** Extract every Scanner-coupled or 3-tab-coupled assertion into dedicated files,
leave the mode-agnostic tests behind parameterised on `ShellConfig` rather than the literal `3`,
and let `configure_mode.sh` toggle a single `exclude:` entry inside a marker region in each test
target's manifest. `--prune` deletes the extracted files.

## Relevant Files & Context Pointers

Files to split (the coupling in each):

- `Packages/Shell/Tests/ShellTests/FeatureBlindRenderTests.swift` — `tabCount: 3`, `ScannerRoot`
- `Packages/Shell/Tests/ShellTests/ReTapTests.swift` — `tabCount: 3`
- `Packages/Shell/Tests/ShellTests/TeardownTests.swift` — `tabCount: 3`
- `Packages/Shell/Tests/ShellTests/TestSupport.swift` — shared Scanner fixtures
- `Packages/Shell/Tests/ShellTests/PackageManifestTests.swift` — asserts the Scanner package edge
- `App/Tests/AppTests/AppCompositionTests.swift` — provider count, tab-1 routing
- `App/Tests/AppTests/ShellTabResolverTests.swift` — `ScannerRoot` placement
- `App/Tests/AppTests/DeepLinkCompositionTests.swift` — `ScannerRoot` resolution
- `App/Tests/AppTests/DeepLinkFlowTests.swift` — end-to-end Scanner deep link
- `App/Tests/AppTests/NavigationFlowTests.swift` — cross-tab navigation via Scanner
- `App/UITests/DeepLinkOpenURLUITests.swift` — 3-tab cold-start assertion

New files: `Packages/Shell/Tests/ShellTests/ScannerTabTests.swift`,
`App/Tests/AppTests/ScannerCompositionTests.swift`,
`App/Tests/AppTests/ScannerDeepLinkTests.swift`,
`App/UITests/ScannerTabUITests.swift`.

Also: `Packages/Shell/Package.swift` and the App test target in `Project.swift` — add the
`exclude:` marker region; `scripts/configure_mode.sh` — toggle it.

## Design Rationale

- **Extract rather than skip.** `activeMode` is a manifest-level constant, not available at test
  runtime, so an `XCTSkipIf` would need a second source of truth. Excluding files at the manifest
  level keeps one source of truth and means the excluded tests do not even compile in lean mode.
- **Parameterise the survivors.** A test that asserts `tabCount: 3` is really asserting "the shell
  honours its config". Rewriting it against `ShellConfig` makes it valid in every mode and is the
  change a careful developer would make anyway.
- **Do not weaken coverage.** Enterprise mode must still run every assertion that exists today;
  this task moves them, it does not delete them.
- **Applicable skills**: `ios-ui-audit`, `code-health-audit`, `ArchTests`.

### BDD SCENARIOS

Canonical source: [bdd_scenarios.md](bdd_scenarios.md) S21.

```gherkin
Scenario: Enterprise mode retains full coverage  [Tier C - Integration]
  Given the test suite has been split
  When I configure enterprise mode and run the full suite
  Then every assertion that existed before this task still executes
  And the suite is green

Scenario: Lean mode runs a green, Scanner-free suite  [Tier C - Integration]
  Given the test suite has been split
  When I configure lean mode and run the full suite
  Then the suite is green
  And no Scanner-coupled assertion is executed
  And the extracted test files are not compiled

Scenario: Surviving shell tests are config-driven, not literal  [Tier A - Unit]
  Given ShellViewModel is constructed with ShellConfig(tabCount: 2, initialTab: 1)
  When the shell initialises
  Then the router is synced to tab 1
  And the shell manages exactly 2 tab paths
  And no test asserts the literal value 3

Scenario: Re-tap behaviour holds at any tab count  [Tier A - Unit]
  Given a shell configured with N tabs where N is 2 or 3
  When the user re-taps the already-selected tab with a non-empty path
  Then that tab path is popped to root
  And no other tab path is mutated

Scenario: Round-trip restores the excluded tests  [Tier C - Integration]
  Given lean mode has excluded the Scanner test files
  When I run "./scripts/configure_mode.sh enterprise"
  Then the exclude regions are emptied
  And the extracted files compile and run again
  And the suite is green

Scenario: Pruning lean mode removes the extracted tests  [Tier C - Integration]
  Given a clean git tree
  When I run "./scripts/configure_mode.sh lean --prune"
  Then the extracted Scanner test files are deleted along with Features/Scanner
  And the remaining suite compiles and is green
```

## Test & Verification Checklist

- [ ] **RED**: Before splitting, run the full suite in lean mode and record the exact set of
      failures. That failing list is the acceptance target — it must become empty.
- [ ] **GREEN**: Extract the Scanner-coupled assertions into the four new files; rewrite the
      survivors against `ShellConfig`; add the `exclude:` marker regions; extend
      `configure_mode.sh` to toggle them.
- [ ] **REFACTOR**: `swiftformat --config quality/.swiftformat .`,
      `swiftlint lint --strict --config quality/.swiftlint.yml`.
- [ ] **Tier A**: `swift test --package-path Packages/Shell` green in both modes.
- [ ] **Tier B**: `bash scripts/check_module_boundaries.sh` and
      `swift test --package-path ArchTests` pass in enterprise mode.
- [ ] **Tier C**: `tuist generate --no-open && xcodebuild test` green in enterprise **and** lean;
      then a round trip back to enterprise, green again.

## Definition of Done

- Zero failing tests in enterprise mode and zero in lean mode.
- No surviving test asserts a literal tab count; all are driven by `ShellConfig`.
- Enterprise coverage is unchanged — no assertion was deleted, only relocated.
- `--prune` removes the extracted files cleanly.
- SwiftLint strict and SwiftFormat lint clean; clean `git status` after the task commit.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_marker_regions_and_mode_seam.md) and
  [Task 2](task_2_configure_mode_script.md).
- Blocks [Task 10](task_10_acceptance_verification_and_docs.md).

## References & Rollback

- HLD §4.7 (test-suite mode awareness); `bdd_scenarios.md` S21.
- **Rollback**: revert the task commit. The tests return to their current enterprise-only shape;
  lean mode reverts to "builds but red", which Task 10 would then catch.
