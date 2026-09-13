---
id: "task_9_native_plugin_mason_bricks"
status: "todo"
priority: "medium"
assignee: null
epic: "tri_mode_and_flutter_plugin_devbed"
dueDate: null
created: "2026-09-13T21:30:41Z"
modified: "2026-09-13T21:30:41Z"
completedAt: null
labels: ["tooling", "automation", "scaffolding"]
order: "a9"
---

# Task 9: Mason Bricks ios_native_plugin & ios_add_native_ui

Epic: [tri_mode_and_flutter_plugin_devbed](../epic/tri_mode_and_flutter_plugin_devbed/tri_mode_and_flutter_plugin_devbed.en.md)

## Requirement Analysis

Turn the hand-built devbed into a generator, mirroring Android's `native_plugin` and
`add_native_ui` bricks and following this repo's existing `ios_`-prefixed naming
(`ios_mvi_feature`, `ios_mvi_subfeature`, `ios_remove_feature`, `ios_remove_subfeature`).

- **`ios_native_plugin`** — emits the four-layer package for a named plugin, with
  `has_ui: true|false`. With UI it includes `Presentation/` plus `PlatformViewFactory` and
  `PlatformView`; without UI it emits the Pigeon host-API path and no `Presentation/` at all.
- **`ios_add_native_ui`** — the one-shot No-UI → With-UI upgrade, adding the SwiftUI screen,
  ViewModel, MVI contracts, `PlatformView` and `PlatformViewFactory` to an existing plugin.

The hard requirement: **output must match what `pac_native_plugin` emits in
`bloc_digital_wallet`**, because generated code is meant to be copied straight into a real
plugin's `ios/` directory. A drift here silently produces plugins that do not build in their
actual home.

## Relevant Files & Context Pointers

- `bricks/ios_native_plugin/brick.yaml`, `__brick__/`, `hooks/`
- `bricks/ios_add_native_ui/brick.yaml`, `__brick__/`, `hooks/`
- `mason.yaml` — register both bricks.
- `scripts/test_mason_bricks.sh` — **new**, generates into a temp dir and diffs the layout.
- Contract to match: `bloc_digital_wallet/bricks/pac_native_plugin/__brick__/packages/{{name.snakeCase()}}/ios/`
  and `bloc_digital_wallet/bricks/pac_add_native_ui/__brick__/`.
- Android reference: `android_digital_wallet/bricks/native_plugin/`, `.../add_native_ui/`.
- Existing local conventions to copy: `bricks/ios_mvi_feature/`.

## Design Rationale

- **Generate from the proven tree.** Tasks 6–8 produce a working package; the brick is a
  parameterisation of that exact tree, not a fresh design. This is why the bricks come last.
- **`has_ui` prunes in a post-gen hook**, matching `pac_native_plugin` — SwiftPM globs
  `Sources/<name>/**`, so one manifest serves both modes and the hook deletes the unused folders.
- **Diff, do not eyeball.** `test_mason_bricks.sh` compares the generated file list against the
  Flutter brick's structure, so drift fails CI instead of surfacing in someone's plugin.
- **Naming follows the repo, not Android.** Android has `native_plugin`; this repo prefixes every
  brick with `ios_`, and internal consistency wins over cross-repo symmetry for file names.
- **Applicable skills**: Mason (`mason make`), `ios-ui-audit`, `architecture-audit`.

### BDD SCENARIOS

Canonical source: [bdd_scenarios.md](../epic/tri_mode_and_flutter_plugin_devbed/bdd_scenarios.md) S20.

```gherkin
Scenario: The brick emits a with-UI plugin  [Tier C - Integration]
  Given the devbed bricks are registered in mason.yaml
  When I run "mason make ios_native_plugin --name biometric_auth --has_ui true"
  Then a four-layer package is emitted with Platform, Domain, Data and Presentation
  And its container subclasses SharedContainer using FactoryKit 3.3.2
  And a PlatformViewFactory and PlatformView are present
  And the emitted layout matches pac_native_plugin's with-UI output

Scenario: The brick emits a headless plugin  [Tier C - Integration]
  When I run "mason make ios_native_plugin --name biometric_auth --has_ui false"
  Then no Presentation directory is emitted
  And the Pigeon host API path is present
  And the emitted layout matches pac_native_plugin's no-UI output

Scenario: Generated names follow the naming convention  [Tier A - Unit]
  Given the brick is run with name "biometric_auth"
  Then types are PascalCase such as BiometricAuthPlugin and BiometricAuthContainer
  And the package directory is snake_case
  And the library product name uses the param-case form

Scenario: The generated package builds  [Tier C - Integration]
  Given a plugin generated with has_ui true into the devbed
  And the devbed has been bootstrapped
  When I build it with the documented xcodebuild invocation
  Then the build succeeds and its tests pass

Scenario: The upgrade brick adds UI to a headless plugin  [Tier C - Integration]
  Given a plugin previously generated with has_ui false
  When I run "mason make ios_add_native_ui --name biometric_auth"
  Then Presentation, PlatformView and PlatformViewFactory are added
  And no existing Domain, Data or Platform file is overwritten
  And the package still builds

Scenario: Re-running the upgrade brick is safe  [Tier A - Unit]
  Given a plugin that already has UI
  When I run ios_add_native_ui against it again
  Then the developer is warned rather than silently overwriting customised files

Scenario: Brick output drift is caught  [Tier C - Integration]
  Given pac_native_plugin's structure is the contract
  When "./scripts/test_mason_bricks.sh" runs
  Then any missing or extra emitted file is reported as a failure
```

## Test & Verification Checklist

- [ ] **RED**: Write `scripts/test_mason_bricks.sh` first — generate into a temp dir and diff
      against the `pac_native_plugin` file list. Confirm it fails before the bricks exist.
- [ ] **GREEN**: Build both bricks by parameterising the Task 6–8 tree; add the `has_ui` post-gen
      hook; register both in `mason.yaml`.
- [ ] **REFACTOR**: Ensure generated Swift passes `swiftformat --lint` and
      `swiftlint --strict` as emitted — a brick that emits lint-dirty code is a broken brick.
- [ ] **Tier A**: Generated package's own tests pass via the documented `xcodebuild` invocation.
- [ ] **Tier B**: `swiftlint --strict` and `swiftformat --lint` clean, including generated output.
- [ ] **Tier C**: `./scripts/test_mason_bricks.sh` green for all four combinations
      (`has_ui` true/false × fresh/upgrade).

## Definition of Done

- Both bricks registered in `mason.yaml` and runnable.
- Output matches `pac_native_plugin` / `pac_add_native_ui` structure, verified by diff.
- Generated code compiles, tests pass, and is lint- and format-clean as emitted.
- `scripts/test_mason_bricks.sh` covers all four combinations.
- Clean `git status` after the commit.

## Dependencies & Blockers

- Blocked by [Task 7](task_7_flutter_platform_layer.md) — the bricks parameterise its output.
- Blocks [Task 10](task_10_acceptance_verification_and_docs.md).

## References & Rollback

- HLD §7 (brick table); `bdd_scenarios.md` S20.
- Contract: `bloc_digital_wallet/bricks/pac_native_plugin/`, `.../pac_add_native_ui/`.
- **Rollback**: revert the commit and unregister the bricks from `mason.yaml`. The hand-built
  `Plugin/` devbed is unaffected.
