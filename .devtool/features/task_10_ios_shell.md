---
id: "task_10_ios_shell"
status: "todo"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: null
labels: ["architecture", "spm", "shell", "mvi", "navigation"]
order: "a10"
---

# Task 10: `Shell` package — ShellView + ShellViewModel + HomeStubView

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: A (behavioral).** Emission order on tab changes + per-tab popToRoot on re-tap are the risk areas.

## Requirement Analysis

`Packages/Shell/` — depends on `Platform`, `Framework`, `AppUIKit`. **Never** a Feature (ArchTests K6). The tab container; feature-blind — it resolves tab content through `AppRouter.destination(for:)`.

```
Sources/Shell/
├── ShellView.swift        TabView(selection: $router.selectedTab); per tab a NavigationStack(path: $router.tabPaths[i])
│                          with .navigationDestination(for: <each concrete AppRoute type>) { router.destination(for: $0) }
│                          tab 0 root = HomeStubView(); tab 1 root = router.destination(for: AppRoutes.ScannerRoot());
│                          tab 2 root = router.destination(for: AppRoutes.SettingsRoot())
├── ShellViewModel.swift   MviViewModel<ShellState, ShellAction, ShellEvent>
├── ShellState.swift       struct { var selectedTab: Int }
├── ShellAction.swift      enum { case selectTab(Int) }
├── ShellEvent.swift       enum { case scrollToTop(tab: Int) }
├── ShellConfig.swift      public struct { tabCount, initialTab } — App passes this in
└── Tabs/HomeStubView.swift  icon + "Home", no logic
```

Behavior:
- `dispatch(.selectTab(i))` where `i != selectedTab` → `reduce { $0.selectedTab = i }`, `router.switchTab(i)`, `AppEventBus.publish(ShellTabVisibilityChanged(tabIndex: prev, isVisible: false))` then `...(tabIndex: i, isVisible: true)`.
- `dispatch(.selectTab(i))` where `i == selectedTab` (re-tap) → `router.popToRoot(inTab: i)` and `emit(.scrollToTop(tab: i))`. No state change, no visibility events.
- `ShellView` binds `selectedTab` from the router (single source of truth) and forwards user taps through `viewModel.dispatch(.selectTab(_:))`.

The `AppRouter` + `AppEventBus` instances are **injected** (constructor / environment) by the App composition root (Task 12), not created here.

## Relevant Files & Context Pointers

- `Packages/Shell/Package.swift`, `Packages/Shell/Sources/Shell/**`, `Packages/Shell/Tests/ShellTests/**` — **NEW**
- `Tuist/Package.swift` — marker-region entry for `Packages/Shell`
- Source Spec §4.1, §6.1 (per-tab nav), §8 (lifecycle events), Changelog #4, #6
- ArchTests K6 (Shell depends on 0 Features) — enabled in Task 12

## Design Rationale

Default tab = 2 (Settings) — the most complete Feature, so a fresh clone shows real MVI immediately (matches Flutter/Android). `ShellViewModel : MviViewModel` keeps the host under the same MVI discipline it asks of Features. Feature-blindness (Changelog #6) is achievable on iOS because the App registers `RouteProvider`s and the Shell only ever calls `router.destination(for:)` — no `import SettingsFeature` anywhere in `Shell`.

**Applicable skills:** none specific.

### BDD Scenarios

```gherkin
# Happy path
Scenario: cold start selects the configured initial tab
  Given ShellConfig(tabCount: 3, initialTab: 2)
  Then ShellViewModel.uiState.selectedTab == 2 and router.selectedTab == 2

Scenario: selecting a different tab updates state and router
  When dispatch(.selectTab(0)) from 2
  Then uiState.selectedTab == 0 and router.switchTab(0) was called

# Emission order
Scenario: switching tabs publishes visibility events old-then-new
  When dispatch(.selectTab(1)) from 2
  Then the bus received exactly [ShellTabVisibilityChanged(2,false), ShellTabVisibilityChanged(1,true)] in that order

Scenario: uiState @Published emits [initial, .selectTab result] in order across a switch

# State transitions
Scenario: re-tapping the active tab does NOT change selectedTab and publishes NO visibility events
  When dispatch(.selectTab(2)) while selectedTab == 2
  Then uiState is unchanged, bus received nothing, router.popToRoot(inTab: 2) was called, event .scrollToTop(2) emitted

Scenario: selectTab with an out-of-range index is ignored (no crash, no state change)

# Async / race
Scenario: three rapid dispatch(.selectTab) with distinct indices end at the last index
  When dispatch(.selectTab(0)), (.selectTab(1)), (.selectTab(2)) with no await
  Then uiState.selectedTab == 2 and the visibility events form a consistent old->new chain with no gaps

# Feature-blindness (structural)
Scenario: Shell renders tab 2 via a fake RouteProvider
  Given a MockRouteProvider registered for AppRoutes.SettingsRoot() returning Text("fake settings")
  When ShellView is hosted
  Then tab 2 shows "fake settings" without Shell importing any Feature module

# Resource teardown
Scenario: ShellViewModel.onClear() empties cancellables/effectTasks; no bus emission afterward
```

### TDD Tests

- `ShellViewModelTests` — initial tab; `selectTab` different vs same; out-of-range ignored; rapid-switch final state.
- `TabVisibilityEmissionTests` — a bus `record()` sink asserts the exact `[old(false), new(true)]` array; re-tap → empty.
- `ReTapTests` — `router` spy asserts `popToRoot(inTab:)`; `eventSubject` sink asserts `.scrollToTop`.
- `FeatureBlindRenderTest` — host `ShellView` in `UIHostingController` with a `MockRouteProvider`; assert content resolves; grep the `Shell` sources in-test for `import .*Feature` → none.
- `TeardownTests` — per §9A category 7.
- `@MainActor`; injected `AppRouter` (real) + spy where needed; `AppEventBus` a fresh instance per test.

### RED → GREEN

- RED: emission-order test fails if events are published new-only or in the wrong order; re-tap test fails if `selectTab` always reduces.
- GREEN: implement `ShellViewModel` branching on `i == selectedTab`.

## Definition of Done

- `swift test --package-path Packages/Shell` green; every scenario has a passing test.
- Visibility events proven ordered old→new; re-tap proven to popToRoot + emit scrollToTop with no state/bus change.
- `FeatureBlindRenderTest` passes and the in-test grep finds no Feature import in `Shell`.
- `Package.swift` deps == `[Platform, Framework, AppUIKit]`. Coverage ≥ 80%. SwiftLint/SwiftFormat clean.

## Dependencies & Blockers

- Blocked by [Task 5](task_5_ios_framework_package.md), [Task 7](task_7_ios_appuikit_package.md), [Task 8](task_8_ios_platform_package.md), [Task 9](task_9_ios_rewire_arch_doc.md).
- Blocks [Task 12](task_12_ios_scanner_and_composition.md) (App wires Shell + providers).

## References & Rollback

- Source Spec §4.1, §6.1, §8.
- Rollback: remove `Packages/Shell/` + marker line. App reverts to the Phase 1 placeholder.
