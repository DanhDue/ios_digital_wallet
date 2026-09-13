---
id: "task_6_scaffold_plugin_clean_architecture"
status: "todo"
priority: "high"
assignee: null
epic: "tri_mode_and_flutter_plugin_devbed"
dueDate: null
created: "2026-09-13T21:29:54Z"
modified: "2026-09-13T21:29:54Z"
completedAt: null
labels: ["architecture", "feature", "flutter-interop"]
order: "a6"
---

# Task 6: Scaffold the Plugin Clean Architecture Package

Epic: [tri_mode_and_flutter_plugin_devbed](tri_mode_and_flutter_plugin_devbed.en.md)

## Requirement Analysis

Build the non-Flutter half of the devbed: the SPM package `Plugin/` with its DI container, Domain,
Data and Presentation layers, plus the background task. The Flutter-facing `Platform/` layer is
Task 7 — splitting them means that if the engine binding misbehaves, the failure is isolated to a
single commit.

Mirrors Android's `:plugin` module one-to-one (HLD §4.8), with two deliberate iOS substitutions:

- **DI**: FactoryKit 3.3.2, a `PluginContainer: SharedContainer` subclass — *not* the host's
  global `Container.shared` on Factory 2.4.3, and *not* a hand-written double-checked singleton.
  FactoryKit already provides the thread safety Android had to write by hand in
  `PluginComponentProvider`.
- **Background**: `BGTaskScheduler` in place of `WorkManager`, proving the same property — the
  work runs with **zero Flutter engine**.

`platforms: [.iOS("15.0")]` sits deliberately below the template's iOS 16 floor, because this
package's consumer is a Flutter app rather than this template, and it must match what
`pac_native_plugin` emits. This is the one place `Module.swift` is not the deployment-target
authority; record the reason in the package header.

## Relevant Files & Context Pointers

- `Plugin/Package.swift` — FactoryKit 3.3.2 + the `Flutter` binary target from Task 5.
- `Plugin/Sources/Plugin/PluginContainer.swift`
- `Plugin/Sources/Plugin/Domain/Model/PluginData.swift`
- `Plugin/Sources/Plugin/Domain/Repository/PluginRepository.swift`
- `Plugin/Sources/Plugin/Domain/UseCase/GetDataUseCase.swift`, `SyncDataUseCase.swift`
- `Plugin/Sources/Plugin/Data/Repository/PluginRepositoryImpl.swift`
- `Plugin/Sources/Plugin/Data/Background/DataSyncTask.swift`
- `Plugin/Sources/Plugin/Presentation/Base/MviViewModel.swift`, `ViewContract.swift`
- `Plugin/Sources/Plugin/Presentation/MyPluginViewModel.swift`, `MyPluginState.swift`,
  `MyPluginAction.swift`, `MyPluginEvent.swift`, `MyPluginView.swift`
- `Plugin/Tests/PluginTests/PluginContainerTests.swift`, `MyPluginViewModelTests.swift`,
  `DataSyncTaskTests.swift`
- Shape references: `bloc_digital_wallet/bricks/pac_native_plugin/__brick__/.../ios/` (the target
  output) and `android_digital_wallet/plugin/src/main/kotlin/com/danhdue/plugin/` (the mirror).

## Design Rationale

- **Domain stays pure Swift.** No `import SwiftUI`, `UIKit`, `Combine` or `Flutter` anywhere under
  `Domain/` — the same rule the host template enforces via ArchTests, applied by review here since
  ArchTests does not scan `Plugin/`.
- **A dedicated container, not the global one.** Two plugins in one Flutter app must not collide on
  factory names, which is exactly why `pac_native_plugin` subclasses `SharedContainer`.
- **MVI base duplicated, not imported.** The plugin cannot depend on `Packages/Framework` — it
  ships into a Flutter app that has no such package. A small local `MviViewModel` is the correct
  duplication, and it matches Android's `presentation/base/`.
- **`BGTaskScheduler.register` must be called before `didFinishLaunching` returns.** A plugin's
  `register(with:)` runs inside that window (Task 7); `SampleApp.init` is the devbed equivalent
  (Task 8). `DataSyncTaskTests` calls the handler directly, so it needs neither scheduler nor app.
- **Applicable skills**: `ios-ui-audit`, `architecture-audit`, `code-health-audit`.

### BDD SCENARIOS

Canonical source: [bdd_scenarios.md](bdd_scenarios.md) S12, S15.

```gherkin
Scenario: The container resolves the default implementation  [Tier A - Unit]
  Given a PluginContainer subclassing SharedContainer
  When I resolve PluginContainer.shared.repository()
  Then a PluginRepositoryImpl instance is returned

Scenario: Tests can override and reset the container  [Tier A - Unit]
  Given a test registers a mock via PluginContainer.shared.repository.register
  When the repository is resolved
  Then the mock is returned
  When PluginContainer.shared.manager.reset() runs in teardown
  Then resolution returns the default implementation again

Scenario: Two containers do not collide  [Tier A - Unit]
  Given a second plugin defines its own SharedContainer subclass with a factory of the same name
  When both are resolved
  Then each returns its own registration
  And neither affects the global Container.shared

Scenario: The use case maps domain data  [Tier A - Unit]
  Given a repository stub returning a known PluginData
  When GetDataUseCase executes
  Then the returned model equals the stub's value
  When the repository throws
  Then the error propagates unchanged to the caller

Scenario: The view model reduces actions into state  [Tier A - Unit]
  Given MyPluginViewModel in its initial state
  When a load action is dispatched and the use case succeeds
  Then state transitions from idle to loading to loaded with the data
  When the use case fails
  Then state transitions to an error state carrying the message
  And no further state is emitted after the error

Scenario: Rapid repeat actions do not race  [Tier A - Unit]
  Given a slow use case
  When two load actions are dispatched in quick succession
  Then the first in-flight task is cancelled
  And exactly one loaded state is emitted

Scenario: Background sync runs with zero Flutter engine  [Tier A - Unit]
  Given DataSyncTask is registered for identifier "com.danhdue.plugin.sync"
  When the handler is invoked with a BGProcessingTask
  Then dependencies are resolved through PluginContainer
  And no FlutterEngine is instantiated at any point
  And the task completes with success true when the use case succeeds

Scenario: An expiring background task cancels cleanly  [Tier A - Unit]
  Given a sync task is in flight
  When the system invokes the expiration handler
  Then the in-flight work is cancelled
  And the task completes with success false

Scenario: Domain is free of framework imports  [Tier A - Unit]
  Given every file under Plugin/Sources/Plugin/Domain
  When its imports are inspected
  Then none imports SwiftUI, UIKit, Combine or Flutter
```

## Test & Verification Checklist

- [ ] **RED**: Write `PluginContainerTests`, `MyPluginViewModelTests` and `DataSyncTaskTests` from
      the scenarios above and confirm they fail for the right reasons before any implementation.
- [ ] **GREEN**: Implement the container, Domain, Data, background task and Presentation layers —
      minimal code to pass, nothing speculative.
- [ ] **REFACTOR**: `swiftformat --config quality/.swiftformat .`,
      `swiftlint lint --strict --config quality/.swiftlint.yml`; keep functions under 20 lines and
      forbid force-unwrap / `try!`.
- [ ] **Tier A**: `xcodebuild test -scheme Plugin` (the invocation documented in Task 5) green.
- [ ] **Tier B**: `swiftlint --strict` and `swiftformat --lint` clean across `Plugin/`.
- [ ] **Tier C**: Deferred to [Task 8](task_8_scaffold_sample_runner_app.md), which mounts this
      package in a runnable app.

## Definition of Done

- `Plugin/` compiles via the documented `xcodebuild` invocation.
- All three test classes pass; every scenario above is covered.
- `Domain/` imports nothing but the Swift standard library and `Foundation`.
- Package header records why `platforms` is iOS 15 rather than the template's iOS 16.
- SwiftLint strict and SwiftFormat lint clean; clean `git status` after the commit.

## Dependencies & Blockers

- Blocked by [Task 5](task_5_bootstrap_devbed_flutter_binding.md).
- Blocks [Task 7](task_7_flutter_platform_layer.md), [Task 8](task_8_scaffold_sample_runner_app.md).

## References & Rollback

- HLD §4.8 (layout), §4.5(a) (Factory version split); `bdd_scenarios.md` S12, S15.
- Target shape: `bloc_digital_wallet/bricks/pac_native_plugin/__brick__/packages/*/ios/`.
- Android mirror: `android_digital_wallet/plugin/src/main/kotlin/com/danhdue/plugin/`.
- **Rollback**: revert the commit; `Plugin/` disappears and no host mode is affected.
