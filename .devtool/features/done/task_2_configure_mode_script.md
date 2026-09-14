---
id: "task_2_configure_mode_script"
status: "done"
priority: "high"
assignee: null
epic: "tri_mode_and_flutter_plugin_devbed"
dueDate: null
created: "2026-09-13T21:29:15Z"
modified: "2026-09-14T14:52:00+07:00"
completedAt: "2026-09-14T14:52:00+07:00"
labels: ["tooling", "automation", "scripting"]
order: "a2"
---

# Task 2: Implement scripts/configure_mode.sh

Epic: [tri_mode_and_flutter_plugin_devbed](../epic/tri_mode_and_flutter_plugin_devbed/tri_mode_and_flutter_plugin_devbed.en.md)

## Requirement Analysis

The mode switch itself. Same CLI contract as the Android template's `scripts/configure_mode.sh`
so the two repos stay operationally identical:

```bash
scripts/configure_mode.sh <enterprise|lean|plugin> [--prune] [--force] [--root-dir=<path>]
```

Per mode:

- **`enterprise`** — `activeMode = .enterprise`; uncomment every marker region; restore the 3-tab
  layout and `ShellConfig` defaults `tabCount: 3, initialTab: 2`; regenerate.
- **`lean`** — `activeMode = .lean`; comment the Scanner imports, route provider, shell tab and
  tab-resolver case; set Settings to index 1 and defaults `tabCount: 2, initialTab: 1`;
  regenerate. `--prune` deletes `Features/Scanner/`.
- **`plugin`** — `activeMode = .plugin`; call `bootstrap_devbed.sh`; regenerate.
  `--prune` deletes `App/`, `Packages/`, `Features/`, `ArchTests/`.

`--prune` must abort on a dirty `git status --porcelain` unless `--force` is given. The script
must be idempotent: running it twice for the same mode is a no-op the second time.

Note on ordering: the `plugin` branch calls `bootstrap_devbed.sh`, which Task 5 delivers. Until
Task 5 lands, the `plugin` branch should fail with a clear "not yet implemented" message rather
than half-configuring the tree; wire it up in Task 5.

## Relevant Files & Context Pointers

- `scripts/configure_mode.sh` — **new**.
- `scripts/test_configure_mode.sh` — **new**, the harness for this script.
- `Tuist/ProjectDescriptionHelpers/ActiveMode.swift` — written by this script (from Task 1).
- `App/Sources/Composition/AppComposition.swift`, `App/Sources/Composition/DeepLinkComposition.swift`,
  `Packages/Shell/Sources/Shell/ShellView.swift`, `Packages/Shell/Sources/Shell/ShellConfig.swift`
  — the four marker-region targets.
- Reference implementation (263 lines, already proven):
  `android_digital_wallet/scripts/configure_mode.sh`.
- Existing portable-sed helpers to reuse: `scripts/rename_project.sh` lines ~162-182
  (`replace_in`, BSD vs GNU sed detection).

## Design Rationale

- **Reuse the Android CLI contract verbatim** so a developer moving between the two templates does
  not have to relearn the tool.
- **Reuse `rename_project.sh`'s portable-sed detection** rather than inventing a second one —
  macOS BSD sed and GNU sed differ on `-i`, and that bug has already been solved once in this repo.
- **Comment/uncomment must preserve indentation** and use `// ` so SwiftFormat does not rewrite it.
- **Idempotency is a test, not a hope** — `test_configure_mode.sh` asserts that a second run
  produces a byte-identical tree.
- **Applicable skills**: Tuist (`tuist generate`), `quality_check`, `ArchTests`.

### BDD SCENARIOS

Canonical source: [bdd_scenarios.md](../epic/tri_mode_and_flutter_plugin_devbed/bdd_scenarios.md) S1–S8.

```gherkin
Scenario: Switching to lean unwires Scanner everywhere  [Tier C - Integration]
  Given the project is in enterprise mode
  When I run "./scripts/configure_mode.sh lean"
  Then activeMode is .lean
  And "import Scanner" and the ScannerRouteProvider registration are commented out
  And the shell:scanner-tab region is commented out
  And the app:tab-resolver-scanner region is commented out
  And ShellConfig defaults become tabCount 2 and initialTab 1
  And "tuist generate --no-open" and "xcodebuild build" both succeed

Scenario: Switching back to enterprise restores the governance gate  [Tier C - Integration]
  Given the project is in lean mode
  When I run "./scripts/configure_mode.sh enterprise"
  Then every marker region is uncommented
  And ShellConfig defaults become tabCount 3 and initialTab 2
  And "swift test --package-path ArchTests" passes, including K10.2
  And "bash scripts/check_module_boundaries.sh" passes

Scenario: The script is idempotent  [Tier A - Unit]
  Given the project is already in lean mode
  When I run "./scripts/configure_mode.sh lean" a second time
  Then the working tree is byte-identical to before the second run
  And the exit status is zero

Scenario: Round-trip through all three modes loses nothing  [Tier C - Integration]
  Given a clean git tree in enterprise mode
  When I run configure_mode.sh for lean, then plugin, then enterprise
  Then every Swift source and Tuist manifest parses
  And no source file has been lost
  And the build is green at each intermediate state

Scenario: --prune deletes only what the mode does not use  [Tier C - Integration]
  Given a clean git tree in enterprise mode
  When I run "./scripts/configure_mode.sh lean --prune"
  Then "Features/Scanner" no longer exists
  And "tuist generate --no-open" reports no missing dependency
  And "xcodebuild build" succeeds

Scenario: --prune refuses a dirty tree  [Tier A - Unit]
  Given at least one uncommitted modification exists
  When I run "./scripts/configure_mode.sh lean --prune"
  Then the exit status is non-zero
  And the error names the dirty tree and the --force override
  And nothing has been deleted and no manifest modified

Scenario: An invalid mode is rejected  [Tier A - Unit]
  When I run "./scripts/configure_mode.sh turbo"
  Then the exit status is non-zero and usage is printed
  And the working tree is untouched

Scenario: Two modes cannot be passed at once  [Tier A - Unit]
  When I run "./scripts/configure_mode.sh lean enterprise"
  Then the exit status is non-zero and the error names both modes
```

## Test & Verification Checklist

- [ ] **RED**: Write `scripts/test_configure_mode.sh` first, covering every scenario above against
      a `--root-dir` copy of the repo. Confirm it fails before `configure_mode.sh` exists.
- [ ] **GREEN**: Implement `configure_mode.sh` until the harness passes. The `plugin` branch may
      exit with "not yet implemented" pending Task 5.
- [ ] **REFACTOR**: `shellcheck` clean; extract shared sed helpers; keep functions under 20 lines.
- [ ] **Tier B**: After an `enterprise` run — `swift test --package-path ArchTests` and
      `bash scripts/check_module_boundaries.sh` pass. `swiftlint --strict` and
      `swiftformat --lint` clean in both enterprise and lean.
- [ ] **Tier C**: `enterprise → lean → enterprise` round trip with `tuist generate --no-open` and
      `xcodebuild build` green at each state.

## Definition of Done

- `scripts/configure_mode.sh` implements all three modes with `--prune`, `--force`, `--root-dir`.
- `scripts/test_configure_mode.sh` covers all eight scenarios and passes.
- Idempotency proven by a byte-identical second run.
- Round trip `enterprise → lean → enterprise` restores a fully green governance gate.
- Clean `git status` after the task commit.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_marker_regions_and_mode_seam.md).
- Blocks [Task 3](task_3_mode_aware_test_suite.md), [Task 4](task_4_rename_project_mode_integration.md).
- The `plugin` branch is completed by [Task 5](task_5_bootstrap_devbed_flutter_binding.md).

## References & Rollback

- HLD §4.3 (sequence), §4.6 (mode seam); `bdd_scenarios.md` S1–S8.
- Android reference: `android_digital_wallet/scripts/configure_mode.sh`.
- **Rollback**: the script never runs destructively on a dirty tree, so
  `git checkout -- .` restores any partial switch. Revert the task commit to remove the script.
