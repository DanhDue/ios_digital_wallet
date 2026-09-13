---
id: "task_8_scaffold_sample_runner_app"
status: "todo"
priority: "medium"
assignee: null
epic: "tri_mode_and_flutter_plugin_devbed"
dueDate: null
created: "2026-09-13T21:30:41Z"
modified: "2026-09-13T21:30:41Z"
completedAt: null
labels: ["feature", "testing", "flutter-interop"]
order: "a8"
---

# Task 8: Scaffold the Sample Runner App

Epic: [tri_mode_and_flutter_plugin_devbed](../epic/tri_mode_and_flutter_plugin_devbed/tri_mode_and_flutter_plugin_devbed.en.md)

## Requirement Analysis

The payoff of the whole devbed: a standalone SwiftUI app that mounts the plugin's screen and
drives its use cases **without a Flutter engine**, so iteration is an Xcode run rather than a
full Flutter app launch. Mirrors Android's `:sample` module (`MainActivity` + `SampleApp`).

The Sample app:

- mounts `MyPluginView()` directly, bypassing `FlutterPlatformView` — proving the SwiftUI layer is
  independently runnable;
- calls `DataSyncTask.register()` from `SampleApp.init`, the devbed stand-in for a plugin's
  `register(with:)`, honouring the rule that `BGTaskScheduler.register` must run before
  `didFinishLaunching` returns;
- offers a control that triggers the same `SyncDataUseCase` the Pigeon path calls, so both entry
  points are exercised from one place.

`Project.swift` declares the Sample app target only when `activeMode == .plugin` (Task 1 seam).

## Relevant Files & Context Pointers

- `Sample/Sources/SampleApp.swift` — `@main`, registers the BGTask identifier.
- `Sample/Sources/ContentView.swift` — mounts `MyPluginView()`, plus the sync trigger control.
- `Sample/Resources/Info.plist` — `BGTaskSchedulerPermittedIdentifiers` must list
  `com.danhdue.plugin.sync`, or registration traps at runtime.
- `Project.swift` — the Sample app target, inside the `activeMode == .plugin` branch.
- `Tuist/ProjectDescriptionHelpers/Module.swift` — reuse the shared target factory.
- `docs/architecture/PLUGIN_DEVBED.md` — document the run loop for plugin authors.
- Android mirror: `android_digital_wallet/sample/src/main/kotlin/com/danhdue/sample/`.

## Design Rationale

- **Mount the SwiftUI view directly, not through `FlutterPlatformView`.** The platform-view wrapper
  is already covered by `MyPlatformViewTests`; the Sample's job is to prove the screen runs with
  no Flutter involvement at all, which is the devbed's entire premise.
- **`Info.plist` permitted identifiers are not optional.** Omitting
  `BGTaskSchedulerPermittedIdentifiers` makes `BGTaskScheduler.register` trap at launch — a
  failure mode worth encoding as a scenario rather than discovering in the simulator.
- **Keep the Sample thin.** It is a testbed, not a demo app: no navigation stack, no design
  system, no localization. Anything richer belongs in the host template's modes.
- **Applicable skills**: `ios-ui-audit`, Tuist (`tuist generate`).

### BDD SCENARIOS

Canonical source: [bdd_scenarios.md](../epic/tri_mode_and_flutter_plugin_devbed/bdd_scenarios.md) S16.

```gherkin
Scenario: The Sample app builds in plugin mode  [Tier C - Integration]
  Given the project is in plugin mode and the devbed is bootstrapped
  When I run "xcodebuild -scheme Sample -destination 'generic/platform=iOS Simulator'"
  Then the build succeeds
  And the Sample target links the Plugin package

Scenario: The Sample app launches without a Flutter engine  [Tier C - Integration]
  Given the Sample app is installed on a simulator
  When it launches
  Then the plugin SwiftUI screen renders
  And no FlutterEngine is instantiated at any point

Scenario: The sync control drives the shared use case  [Tier C - Integration]
  Given the Sample app is running
  When I trigger the sync control
  Then SyncDataUseCase executes through PluginContainer
  And the screen reflects the resulting state

Scenario: The background identifier is registered at launch  [Tier A - Unit]
  Given SampleApp.init runs
  Then DataSyncTask.register() is called before the first scene is created
  And the identifier matches Info.plist BGTaskSchedulerPermittedIdentifiers

Scenario: A missing permitted identifier is caught  [Tier A - Unit]
  Given Info.plist omits BGTaskSchedulerPermittedIdentifiers
  When the app registers the background task
  Then the failure is detected by the verification checklist
  And the documented fix names the required Info.plist key

Scenario: The Sample target exists only in plugin mode  [Tier C - Integration]
  Given the project is in enterprise or lean mode
  When "tuist generate --no-open" runs
  Then no Sample target is present in the generated workspace
  When the project is in plugin mode
  Then the Sample target is present
```

## Test & Verification Checklist

- [ ] **RED**: Write the launch and registration assertions first (a unit test around
      `SampleApp.init` calling `DataSyncTask.register`, and the target-presence check). Confirm
      they fail before the app exists.
- [ ] **GREEN**: Add `SampleApp.swift`, `ContentView.swift`, `Info.plist`, and the Tuist target
      inside the `.plugin` branch.
- [ ] **REFACTOR**: `swiftformat --config quality/.swiftformat .`,
      `swiftlint lint --strict --config quality/.swiftlint.yml`.
- [ ] **Tier A**: `xcodebuild test -scheme Plugin` still green — Sample must not alter plugin
      behaviour.
- [ ] **Tier B**: SwiftLint strict and SwiftFormat lint clean across `Sample/`.
- [ ] **Tier C**: `./scripts/configure_mode.sh plugin && tuist generate --no-open &&
      xcodebuild -scheme Sample -destination 'generic/platform=iOS Simulator'
      CODE_SIGNING_ALLOWED=NO`, then launch on a simulator and confirm the screen renders.

## Definition of Done

- `Sample/` builds and runs on a simulator in plugin mode, rendering the plugin screen.
- No Flutter engine is instantiated at any point in the Sample's lifetime.
- `DataSyncTask.register()` runs at launch and `Info.plist` lists the identifier.
- The Sample target is absent from enterprise and lean graphs.
- SwiftLint strict and SwiftFormat lint clean; clean `git status` after the commit.

## Dependencies & Blockers

- Blocked by [Task 6](task_6_scaffold_plugin_clean_architecture.md) and
  [Task 7](task_7_flutter_platform_layer.md).
- Blocks [Task 10](task_10_acceptance_verification_and_docs.md).

## References & Rollback

- HLD §4.8; `bdd_scenarios.md` S16.
- Android mirror: `android_digital_wallet/sample/src/main/kotlin/com/danhdue/sample/`.
- **Rollback**: revert the commit; `Plugin/` remains buildable and testable, only the runnable
  testbed is lost.
