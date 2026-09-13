---
id: "task_7_flutter_platform_layer"
status: "todo"
priority: "high"
assignee: null
epic: "tri_mode_and_flutter_plugin_devbed"
dueDate: null
created: "2026-09-13T21:30:41Z"
modified: "2026-09-13T21:30:41Z"
completedAt: null
labels: ["architecture", "feature", "flutter-interop"]
order: "a7"
---

# Task 7: Flutter Platform Layer & SwiftUI PlatformView

Epic: [tri_mode_and_flutter_plugin_devbed](tri_mode_and_flutter_plugin_devbed.en.md)

## Requirement Analysis

The only code in the epic that imports `Flutter`, deliberately isolated in its own commit so an
engine-binding problem surfaces here rather than diffused across the devbed.

Build `Plugin/Sources/Plugin/Platform/`, covering both paths a generated plugin can take:

- **Headless (`has_ui: false`)** — Pigeon contracts in `Messages.g.swift` plus
  `MyPluginHostApiImpl` delegating down to the Domain use cases.
- **With UI (`has_ui: true`)** — `MyPlatformViewFactory` registering under view id
  `com.danhdue.plugin/native_view`, and `MyPlatformView` wrapping the Task 6 SwiftUI screen in a
  `UIHostingController` conforming to `FlutterPlatformView`.

`MyPlugin.register(with:)` is the plugin's composition root — the only place holding the
`FlutterPluginRegistrar`. Container overrides that need `registrar.messenger()` belong there, and
so does `DataSyncTask.register()`, because `BGTaskScheduler.register` must run before
`application(_:didFinishLaunchingWithOptions:)` returns and plugin registration falls inside that
window.

Mirrors Android's `plugin/platform/` package one-to-one (`MyPlugin.kt`, `Messages.g.kt`,
`MyPluginHostApiImpl.kt`, `MyPlatformViewFactory.kt`), substituting `UIHostingController` for
`ComposeView`.

## Relevant Files & Context Pointers

- `Plugin/Sources/Plugin/Platform/MyPlugin.swift`
- `Plugin/Sources/Plugin/Platform/Messages.g.swift`
- `Plugin/Sources/Plugin/Platform/MyPluginHostApiImpl.swift`
- `Plugin/Sources/Plugin/Platform/MyPlatformViewFactory.swift`
- `Plugin/Sources/Plugin/Presentation/MyPlatformView.swift`
- `Plugin/Tests/PluginTests/MyPluginHostApiImplTests.swift`, `MyPlatformViewTests.swift`
- `docs/architecture/PLUGIN_DEVBED.md` — the `xcodebuild` invocation established in Task 5.
- Target shape: `bloc_digital_wallet/bricks/pac_native_plugin/__brick__/.../ios/.../Platform/`
  and `.../Presentation/{{name.pascalCase()}}PlatformView.swift`.
- Android mirror: `android_digital_wallet/plugin/src/main/kotlin/com/danhdue/plugin/platform/`.

## Design Rationale

- **One commit owns every `import Flutter`.** If the binary target or the engine version is wrong,
  exactly one commit fails to compile and the cause is unambiguous.
- **The registrar never leaks past `register(with:)`.** Keeping it in the composition root is what
  lets Domain and Data stay testable with no Flutter symbols at all.
- **`UIHostingController` is the `ComposeView` analogue.** `FlutterPlatformView.view()` returns a
  `UIView`; the hosting controller's view is that bridge, and its lifetime must be held by the
  platform view so SwiftUI state is not deallocated mid-render.
- **Pigeon output is generated, not authored.** `Messages.g.swift` is checked in as generated code
  and excluded from lint, matching how `Messages.g.kt` is handled on Android.
- **Applicable skills**: `ios-ui-audit` (hosting-controller lifecycle, body re-evaluation),
  `architecture-audit`.

### BDD SCENARIOS

Canonical source: [bdd_scenarios.md](bdd_scenarios.md) S13, S14.

```gherkin
Scenario: The plugin registers the headless host API  [Tier A - Unit]
  Given a stub FlutterPluginRegistrar
  When MyPlugin.register(with:) runs in the no-UI configuration
  Then MyPluginHostApiSetup.setUp is called with the registrar's messenger
  And a MyPluginHostApiImpl is supplied as the handler

Scenario: The plugin registers the platform view factory  [Tier A - Unit]
  Given a stub FlutterPluginRegistrar
  When MyPlugin.register(with:) runs in the with-UI configuration
  Then a MyPlatformViewFactory is registered under "com.danhdue.plugin/native_view"

Scenario: The host API delegates to the domain layer  [Tier A - Unit]
  Given a MyPluginHostApiImpl backed by a stubbed GetDataUseCase
  When Flutter invokes the host API method
  Then the use case executes exactly once
  And the domain model is mapped to the Pigeon message type

Scenario: Host API errors surface as Pigeon errors  [Tier A - Unit]
  Given the use case throws
  When Flutter invokes the host API method
  Then the failure is returned as a Pigeon error result
  And the process does not crash

Scenario: The factory creates a platform view  [Tier A - Unit]
  Given MyPlatformViewFactory is registered
  When Flutter requests a platform view for the registered id
  Then a MyPlatformView is created wrapping a UIHostingController
  And its view() returns a non-nil UIView

Scenario: The hosting controller is retained by the platform view  [Tier A - Unit]
  Given a MyPlatformView has been created
  When the creating scope exits
  Then the UIHostingController is still retained by the platform view
  And the hosted SwiftUI view continues to render

Scenario: The platform view is driven by the view model  [Tier A - Unit]
  Given a MyPlatformView hosting MyPluginView backed by MyPluginViewModel
  When the view model emits a loaded state
  Then the hosted SwiftUI view reflects that state

Scenario: Detaching from the engine tears down the host API  [Tier A - Unit]
  Given the plugin is attached to an engine
  When the engine detaches
  Then the host API handler is set to nil
  And no retained reference to the messenger remains

Scenario: The Platform layer compiles against the real engine  [Tier C - Integration]
  Given the devbed has been bootstrapped
  When I build the Plugin scheme with the documented xcodebuild invocation
  Then every file importing Flutter compiles
  And the build succeeds
```

## Test & Verification Checklist

- [ ] **RED**: Write `MyPluginHostApiImplTests` and `MyPlatformViewTests` from the scenarios above,
      with a stub `FlutterPluginRegistrar` / messenger. Confirm they fail first.
- [ ] **GREEN**: Implement `MyPlugin`, `MyPluginHostApiImpl`, `MyPlatformViewFactory`,
      `MyPlatformView`, and check in the generated `Messages.g.swift`.
- [ ] **REFACTOR**: `swiftformat --config quality/.swiftformat .`,
      `swiftlint lint --strict --config quality/.swiftlint.yml` (with `Messages.g.swift` excluded
      as generated); no force-unwrap or `try!`.
- [ ] **Tier A**: `xcodebuild test -scheme Plugin` green, including the Task 6 classes.
- [ ] **Tier B**: SwiftLint strict and SwiftFormat lint clean across `Plugin/`.
- [ ] **Tier C**: Deferred to [Task 8](task_8_scaffold_sample_runner_app.md).

## Definition of Done

- Both the headless and with-UI paths are implemented and registered.
- The `FlutterPluginRegistrar` appears nowhere outside `MyPlugin.register(with:)`.
- All five `PluginTests` classes pass together.
- `Messages.g.swift` is checked in and excluded from lint as generated code.
- SwiftLint strict and SwiftFormat lint clean; clean `git status` after the commit.

## Dependencies & Blockers

- Blocked by [Task 5](task_5_bootstrap_devbed_flutter_binding.md) and
  [Task 6](task_6_scaffold_plugin_clean_architecture.md).
- Blocks [Task 8](task_8_scaffold_sample_runner_app.md),
  [Task 9](task_9_native_plugin_mason_bricks.md).

## References & Rollback

- HLD §4.8; `bdd_scenarios.md` S13, S14.
- Android mirror: `android_digital_wallet/plugin/src/main/kotlin/com/danhdue/plugin/platform/`.
- **Rollback**: revert the commit. `Plugin/` falls back to the Flutter-free Task 6 state, which
  still compiles, so the devbed stays usable for Domain and Data work.
