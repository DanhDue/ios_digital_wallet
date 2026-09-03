---
id: "task_1_platform_module"
status: "done"
priority: "high"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T06:57:09Z"
completedAt: "2026-09-02T06:57:09Z"
labels: ["architecture", "feature"]
order: "a1"
---

# Task 1: Create `:platform` module

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

`:platform` is the single cross-feature seam (Goal G4). It carries no feature logic — only:

- **`AppRoutes`** — the shared `NavKey` registry. Seed it by relocating the cross-module route keys that already live in `libraries/framework/src/main/java/com/danhdue/framework/navigation/CommonRoutes.kt` (`HomeRoute`, `LoginRoute`, `CommonRoutes`). Keep them `@Serializable data object ... : NavKey`.
- **`AppEventBus`** — `@Singleton` wrapper over `MutableSharedFlow<AppEvent>(replay = 0, extraBufferCapacity = 64)` exposing `fun publish(event: AppEvent)` and `inline fun <reified T : AppEvent> on(): Flow<T>` (filter by type). Mirror `packages/platform/lib/app_event_bus.dart` from the Flutter template.
- **`AppEvent`** — `sealed interface` base. Define the minimal lifecycle vocabulary: `ShellTabVisibilityChanged(tabIndex: Int, isVisible: Boolean)`, `AppLifecycleChanged(state: Lifecycle.State)`, `UserLoggedOut`.
- **`FeatureEntry`** interface — `fun installer(): EntryProviderInstaller`. Used only by on-demand DFM features (Task 14); install-time features never implement it.
- **`FeatureInstaller`** interface — `suspend fun ensureInstalled(module: String, onReady: () -> Unit)`. Real impl lands in `:app` (Task 14) wrapping `SplitInstallManager`; provide a no-op impl here for tests/JVM.

This task only *creates* the module and moves `CommonRoutes.kt`. Consumers still compile because `:framework` (Task 7) will re-export or depend on `:platform` — until Phase 1, add `:platform` to `settings.gradle.kts` and have `libraries/framework` depend on it so the moved `NavKey`s resolve.

`:platform` depends on `:core` + `:framework` — it needs the `NavKey` type (`androidx.navigation3.runtime`) and the `EntryProviderInstaller` typealias. This is a deliberate deviation from the Flutter `platform` package (which only depends on `core`); see source spec §11.

## Relevant Files & Context Pointers

- `settings.gradle.kts` — add `include(":platform")`
- `buildSrc/src/main/kotlin/Deps.kt`, `buildSrc/src/main/kotlin/extensions/` — add a `PLATFORM` dependency constant
- `libraries/framework/src/main/java/com/danhdue/framework/navigation/CommonRoutes.kt` — source of the `NavKey`s to relocate
- `libraries/framework/src/main/java/com/danhdue/framework/navigation/EntryProviderInstaller.kt` — the typealias `:platform` references
- NEW: `platform/build.gradle.kts`, `platform/src/main/kotlin/com/danhdue/platform/{AppRoutes,AppEventBus,AppEvent,FeatureEntry,FeatureInstaller}.kt`
- Reference: `../../.worktrees/` sibling `bloc_digital_wallet/.worktrees/flutter_super_app_template/packages/platform/lib/{deep_link_routes,app_event_bus}.dart`

## Design Rationale

The bus is a `SharedFlow` (not `StateFlow`) — fire-and-forget broadcast, no replay, matching the Flutter `AppEventBus` posture (publishing before any subscriber is safe; the event is dropped). `AppEvent` subtypes are data contracts, so a feature importing another feature's event *type* is acceptable (same posture as importing a domain entity).

Applicable skill: `@quality_check` after implementation (per `.agent/rules/CRITICAL_RULES.md`).

## TDD Checklist

- [ ] **RED**: `AppEventBusTest` — `publish` then `on<T>()` delivers only matching type; a second subscriber also receives; publish with no subscriber does not throw. Use `turbine` + `runTest`.
- [ ] **RED**: `NoOpFeatureInstallerTest` — `ensureInstalled` invokes `onReady` synchronously.
- [ ] **GREEN**: implement `AppEventBus`, `AppEvent`, `AppRoutes`, `FeatureEntry`, no-op `FeatureInstaller`.
- [ ] **REFACTOR**: extract buffer constants; KDoc each public type; run `detekt` + `spotlessApply`.

## Definition of Done

- `:platform` module builds; `./gradlew :platform:testDebugUnitTest` green.
- `CommonRoutes.kt` no longer in `libraries/framework`; all previous references resolve via `:platform`.
- `./gradlew assembleDebug` green (app unchanged at runtime).
- detekt + spotless clean; new code ≥ 80% line coverage.

## Dependencies & Blockers

- Blocks [Task 2](task_2_konsist_gate.md), [Task 7](task_7_extract_framework_module.md), [Task 11](task_11_platform_routes_settings_pilot.md), [Task 14](task_14_scanner_dynamic_feature.md).
- Not blocked by any task.

## References & Rollback

- Source spec §4.1, §4.4, §5.
- Flutter `packages/platform` (branch `epic/flutter-super-app-template`).
- Rollback: revert the module directory + `settings.gradle.kts` line + restore `CommonRoutes.kt` to `libraries/framework/navigation/`.
