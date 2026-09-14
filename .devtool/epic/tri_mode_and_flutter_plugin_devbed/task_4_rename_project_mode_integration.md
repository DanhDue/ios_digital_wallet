---
id: "task_4_rename_project_mode_integration"
status: "done"
priority: "medium"
assignee: null
epic: "tri_mode_and_flutter_plugin_devbed"
dueDate: null
created: "2026-09-13T21:29:54Z"
modified: "2026-09-14T15:09:00Z"
completedAt: "2026-09-14T15:09:00Z"
labels: ["tooling", "automation", "scripting"]
order: "a4"
---

# Task 4: Integrate --mode into scripts/rename_project.sh

Epic: [tri_mode_and_flutter_plugin_devbed](tri_mode_and_flutter_plugin_devbed.en.md)

## Requirement Analysis

One command should take a fresh clone to a renamed project in the intended mode:

```bash
scripts/rename_project.sh <NewAppName> <new.bundle.id> [<display_name>] \
    [--mode <enterprise|lean|plugin>] [--force] [--dry-run]
```

`--mode` defaults to `enterprise`, so **omitting it must reproduce today's behaviour exactly** —
this is a backwards-compatibility requirement, not a nicety. The script renames first, then
delegates to `configure_mode.sh <mode>`.

Self-verification becomes mode-differentiated:

- `enterprise` — `xcodebuild build` + `swift test --package-path ArchTests` + `check_module_boundaries.sh`
- `lean` — `xcodebuild build` only (this is the point of lean: no `swift-syntax` compile)
- `plugin` — `xcodebuild -scheme Plugin` and `-scheme Sample`; host renaming is a no-op

Under `--dry-run` the script prints `WOULD CONFIGURE MODE: <mode>` and changes nothing.

## Relevant Files & Context Pointers

- `scripts/rename_project.sh` — 458 lines today; extend argument parsing (~line 145 `usage()`),
  add the configure-mode phase after the rename phase, and branch the self-verify phase.
- `scripts/rename_project.sh` lines ~162-182 — existing portable `replace_in` / BSD-vs-GNU sed
  detection; reuse, do not duplicate.
- `scripts/rename_project.sh` lines ~183-253 — the sentinel-window trap; the new phase must not
  break it.
- `scripts/configure_mode.sh` — delegated to (Task 2).
- `scripts/test_rename_project_mode.sh` — **new**, the harness.
- Android reference: `android_digital_wallet/scripts/rename_project.sh`,
  `android_digital_wallet/scripts/test_rename_project_mode.sh`.

## Design Rationale

- **Rename before configure.** Configuring first would leave `configure_mode.sh` patching files
  that are about to be renamed, and the Keychain-service sentinel window must close before the
  tree is restructured.
- **Default `enterprise` is load-bearing.** Existing users and any CI invoking this script must
  see zero change. The harness asserts this explicitly.
- **Dry-run must stay honest.** It already prints what it would rewrite; the mode phase follows
  the same convention rather than silently running.
- **Applicable skills**: Tuist (`tuist generate`), `quality_check`, `ArchTests`.

### BDD SCENARIOS

Canonical source: [bdd_scenarios.md](bdd_scenarios.md) S17–S19.

```gherkin
Scenario: Renaming with --mode lean renames and configures  [Tier C - Integration]
  Given a freshly cloned template with a clean git tree
  When I run "./scripts/rename_project.sh AcmeApp com.acme.app --mode lean"
  Then the app name, bundle id, URL scheme and entry point file are renamed
  And configure_mode.sh lean has been applied
  And "xcodebuild build" succeeds for scheme AcmeApp
  And ArchTests is not executed during self-verification

Scenario: Omitting --mode preserves today's behaviour exactly  [Tier C - Integration]
  Given a freshly cloned template
  When I run "./scripts/rename_project.sh AcmeApp com.acme.app"
  Then the project is configured in enterprise mode
  And all 10 units remain active
  And self-verification runs ArchTests and the boundary guard

Scenario: --dry-run changes nothing  [Tier A - Unit]
  Given a clean git working tree
  When I run "./scripts/rename_project.sh AcmeApp com.acme.app --mode lean --dry-run"
  Then the output contains "WOULD CONFIGURE MODE: lean"
  And "git status --porcelain" reports no changes

Scenario: An invalid mode is rejected before any rename happens  [Tier A - Unit]
  When I run "./scripts/rename_project.sh AcmeApp com.acme.app --mode turbo"
  Then the exit status is non-zero and usage is printed
  And no file has been renamed or modified

Scenario: --mode plugin skips host renaming  [Tier C - Integration]
  Given a Flutter SDK is installed
  When I run "./scripts/rename_project.sh AcmeApp com.acme.app --mode plugin"
  Then the project is configured in plugin mode
  And self-verification builds the Plugin and Sample schemes
  And no host scheme build is attempted

Scenario: The sentinel trap still fires on interruption  [Tier A - Unit]
  Given the rename phase is interrupted mid-flight by a signal
  When the trap runs
  Then the Keychain-service sentinel warning is emitted as before
  And the new mode phase has not executed
```

## Test & Verification Checklist

- [ ] **RED**: Write `scripts/test_rename_project_mode.sh` covering every scenario above against a
      throwaway clone. Confirm the `--mode` scenarios fail before implementation.
- [ ] **GREEN**: Add `--mode` parsing, the configure-mode phase, and the branched self-verify.
- [ ] **REFACTOR**: `shellcheck` clean; no duplicated sed helper; `usage()` documents the flag.
- [ ] **Tier B**: After an enterprise rename — `swift test --package-path ArchTests` and
      `bash scripts/check_module_boundaries.sh` pass under the new name.
- [ ] **Tier C**: Rename to a throwaway name in each of the three modes; `tuist generate --no-open`
      and the mode's build command green in each.

## Definition of Done

- `--mode` accepted, validated, documented in `usage()`, defaulting to `enterprise`.
- Omitting `--mode` is provably identical to current behaviour.
- `--dry-run` leaves the tree untouched and announces the mode phase.
- `scripts/test_rename_project_mode.sh` passes all six scenarios.
- Clean `git status` after the task commit.

## Dependencies & Blockers

- Blocked by [Task 2](task_2_configure_mode_script.md).
- The `--mode plugin` path additionally needs [Task 5](task_5_bootstrap_devbed_flutter_binding.md);
  gate that scenario until Task 5 lands.
- Blocks [Task 10](task_10_acceptance_verification_and_docs.md).

## References & Rollback

- HLD §4.3; `bdd_scenarios.md` S17–S19.
- **Rollback**: revert the task commit; `rename_project.sh` returns to its single-mode form and
  `configure_mode.sh` remains usable standalone.
