---
id: "task_5_bootstrap_devbed_flutter_binding"
status: "todo"
priority: "high"
assignee: null
epic: "tri_mode_and_flutter_plugin_devbed"
dueDate: null
created: "2026-09-13T21:29:54Z"
modified: "2026-09-13T21:29:54Z"
completedAt: null
labels: ["tooling", "automation", "architecture", "flutter-interop"]
order: "a5"
---

# Task 5: Bootstrap the Flutter Engine Binding

Epic: [tri_mode_and_flutter_plugin_devbed](tri_mode_and_flutter_plugin_devbed.en.md)

## Requirement Analysis

The hardest link in the epic, and the one with no Android counterpart. Android writes
`compileOnly("io.flutter:flutter_embedding_debug")` and Maven resolves it. iOS has nothing
equivalent: the `FlutterFramework` package that `pac_native_plugin` depends on is an ephemeral,
generated, **empty** SPM shim — its only source file contains `// Generated file. Do not edit.` —
and `import Flutter` resolves only because Xcode links the real framework at app-build time.
A plugin package therefore **cannot be built standalone**.

This task makes the devbed bind the real engine:

```bash
scripts/bootstrap_devbed.sh [--flutter-root=<path>]
```

It resolves the SDK in order — `$FLUTTER_ROOT`, then fvm (`.fvmrc` / `fvm/versions/<v>`), then
`which flutter` resolved through symlinks — verifies
`<root>/bin/cache/artifacts/engine/ios/Flutter.xcframework` exists, symlinks it to
`Plugin/Vendor/Flutter.xcframework`, and prints the resolved Flutter and engine versions so
drift is visible. It must be idempotent and fail with an actionable message when no SDK is found.

**This task also owns a decision the rest of the devbed depends on.** A package with an
`.xcframework` binary target cannot be built by plain `swift build`; it needs
`xcodebuild -destination`. Establish and document the exact working invocation here, before
Tasks 6–8 are written against it — otherwise the failure surfaces at the end of the epic instead
of the start.

Finally, complete `configure_mode.sh`'s `plugin` branch (stubbed in Task 2) to call this script.

## Relevant Files & Context Pointers

- `scripts/bootstrap_devbed.sh` — **new**.
- `scripts/configure_mode.sh` — replace the `plugin`-branch stub with a real call.
- `.gitignore` — add `Plugin/Vendor/`.
- `Plugin/Package.swift` — the manifest this task validates against (skeleton only; Task 6 fills
  in the sources).
- `docs/architecture/` — **new** `PLUGIN_DEVBED.md` section recording the `xcodebuild` invocation.
- Verified on this machine: `/Users/danhdueexoictif/fvm/versions/3.41.1/bin/cache/artifacts/engine/ios/Flutter.xcframework`.
- Reference shim proving the problem: `bloc_digital_wallet/ios/Flutter/ephemeral/Packages/.packages/FlutterFramework/`.

## Design Rationale

- **Symlink, never copy.** The xcframework is large and machine-specific; copying it into the repo
  invites someone committing it. `Plugin/Vendor/` is git-ignored.
- **Resolution order puts `$FLUTTER_ROOT` first** so CI can pin explicitly, then fvm because that
  is what this machine uses, then `PATH` as the generic fallback.
- **Print the resolved version every run.** Engine drift against the host Flutter app is an
  accepted risk (the devbed compiles and tests, never ships); visibility is the mitigation.
- **Establish the build command here, not later.** Naming the `xcodebuild` invocation in this task
  turns a latent end-of-epic failure into an explicit early acceptance criterion.
- **Applicable skills**: Tuist (`tuist generate`), `quality_check`.

### BDD SCENARIOS

Canonical source: [bdd_scenarios.md](bdd_scenarios.md) S9–S11.

```gherkin
Scenario: Bootstrap resolves the engine via fvm  [Tier A - Unit]
  Given FLUTTER_ROOT is unset
  And fvm has a version installed containing bin/cache/artifacts/engine/ios/Flutter.xcframework
  When I run "./scripts/bootstrap_devbed.sh"
  Then "Plugin/Vendor/Flutter.xcframework" exists as a symlink to that xcframework
  And the script prints the resolved Flutter and engine versions
  And the exit status is zero

Scenario: FLUTTER_ROOT takes precedence over fvm and PATH  [Tier A - Unit]
  Given FLUTTER_ROOT points at a valid SDK
  And a different Flutter version is on PATH
  When I run "./scripts/bootstrap_devbed.sh"
  Then the symlink targets the FLUTTER_ROOT SDK

Scenario: --flutter-root overrides everything  [Tier A - Unit]
  Given FLUTTER_ROOT points at SDK A
  When I run "./scripts/bootstrap_devbed.sh --flutter-root=<SDK B>"
  Then the symlink targets SDK B

Scenario: Bootstrap is idempotent  [Tier A - Unit]
  Given the devbed has already been bootstrapped
  When I run "./scripts/bootstrap_devbed.sh" again
  Then the symlink is unchanged
  And the exit status is zero

Scenario: Bootstrap fails actionably when no SDK is present  [Tier A - Unit]
  Given no Flutter SDK can be found via FLUTTER_ROOT, fvm, or PATH
  When I run "./scripts/bootstrap_devbed.sh"
  Then the exit status is non-zero
  And the message names FLUTTER_ROOT and the --flutter-root override
  And no symlink or directory is created under Plugin/

Scenario: A Flutter SDK without the iOS artifacts fails clearly  [Tier A - Unit]
  Given a Flutter SDK whose bin/cache/artifacts/engine/ios directory is absent
  When I run "./scripts/bootstrap_devbed.sh"
  Then the exit status is non-zero
  And the message names the missing xcframework path and suggests "flutter precache --ios"

Scenario: The plugin package builds against the real engine  [Tier C - Integration]
  Given the devbed has been bootstrapped
  When I build the Plugin scheme with the documented xcodebuild invocation
  Then the build succeeds
  And a source file containing "import Flutter" compiles

Scenario: Plain swift build is documented as unsupported  [Tier A - Unit]
  Given the Plugin package declares an xcframework binary target
  When a developer runs "swift build --package-path Plugin"
  Then the documented guidance directs them to the xcodebuild invocation instead

Scenario: configure_mode.sh plugin triggers bootstrap  [Tier C - Integration]
  Given the devbed has not been bootstrapped
  When I run "./scripts/configure_mode.sh plugin"
  Then bootstrap_devbed.sh runs as part of the switch
  And the Plugin scheme builds afterwards
```

## Test & Verification Checklist

- [ ] **RED**: Write the bootstrap scenarios as shell assertions first (fake SDK roots under a
      temp dir for the negative cases). Confirm they fail before implementation.
- [ ] **GREEN**: Implement `bootstrap_devbed.sh`; add `Plugin/Vendor/` to `.gitignore`; replace
      the `plugin`-branch stub in `configure_mode.sh`.
- [ ] **REFACTOR**: `shellcheck` clean; resolution logic in one function under 20 lines.
- [ ] **Tier B**: `swiftlint --strict` and `swiftformat --lint` stay clean (the script adds no
      Swift, but `Plugin/Package.swift` must be formatted).
- [ ] **Tier C**: `./scripts/configure_mode.sh plugin` then the documented `xcodebuild -scheme
      Plugin -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` succeeds on a
      skeleton source importing Flutter.

## Definition of Done

- `scripts/bootstrap_devbed.sh` resolves via `$FLUTTER_ROOT`, fvm and `PATH`, with
  `--flutter-root` override; idempotent; actionable failures.
- `Plugin/Vendor/` git-ignored and never committed.
- `configure_mode.sh plugin` is no longer a stub.
- **The exact `xcodebuild` invocation for the Plugin package is documented** in
  `docs/architecture/PLUGIN_DEVBED.md` and referenced by Tasks 6–8.
- A skeleton source with `import Flutter` compiles. Clean `git status` after the commit.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_marker_regions_and_mode_seam.md) and
  [Task 2](task_2_configure_mode_script.md).
- Blocks [Task 6](task_6_scaffold_plugin_clean_architecture.md),
  [Task 7](task_7_flutter_platform_layer.md), [Task 8](task_8_scaffold_sample_runner_app.md), and
  the `--mode plugin` path of [Task 4](task_4_rename_project_mode_integration.md).

## References & Rollback

- HLD §4.5(b) (engine binding), §4.8 (layout); `bdd_scenarios.md` S9–S11.
- Flutter's own ephemeral shim: `bloc_digital_wallet/ios/Flutter/ephemeral/Packages/.packages/FlutterFramework/Package.swift`.
- **Rollback**: delete `Plugin/Vendor/` and revert the commit. Nothing in enterprise or lean mode
  touches the devbed, so host builds are unaffected either way.
