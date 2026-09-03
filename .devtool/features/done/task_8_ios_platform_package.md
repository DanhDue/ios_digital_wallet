---
id: "task_8_ios_platform_package"
status: "done"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: "2026-09-03T15:42:42Z"
labels: ["architecture", "spm", "navigation", "events"]
order: "a8"
---

# Task 8: Create `Platform` SPM package (per-tab AppRouter + AppEventBus)

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: A (behavioral).** Per-tab path isolation and event-bus type filtering are the high-risk areas.

## Requirement Analysis

`Packages/Platform/` — depends on `Core` **only** (Changelog #7: nothing here needs `Framework`). The cross-feature seam. Min iOS 16 (`NavigationPath`).

`Sources/Platform/Navigation/`:
- `AppRoute.swift` — `public protocol AppRoute: Hashable {}`.
- `AppRoutes.swift` — namespace enum of cross-feature route values: `struct SettingsRoot: AppRoute`, `struct ScannerRoot: AppRoute`.
- `RouteProvider.swift` — `protocol RouteProvider { func canHandle(_ route: any AppRoute) -> Bool; @ViewBuilder func destination(for route: any AppRoute) -> AnyView }`.
- `AppRouter.swift` — `@MainActor final class AppRouter: ObservableObject` per Source Spec §6.1: `@Published var selectedTab`, `@Published var tabPaths: [NavigationPath]` (one per tab), `register(_:)`, `navigate(to:inTab:)`, `pop(inTab:)`, `popToRoot(inTab:)`, `switchTab(_:)`, `destination(for:)`.

`Sources/Platform/Events/`:
- `AppEvent.swift` — `protocol AppEvent {}` + `ShellTabVisibilityChanged`, `AppLifecycleChanged`, `UserLoggedOut`.
- `AppEventBus.swift` — `final class AppEventBus` with `static let shared`, a `PassthroughSubject<any AppEvent, Never>` (replay 0), `publish(_:)`, `on<T: AppEvent>(_:) -> AnyPublisher<T, Never>`.

`Package.swift`: `Platform` (depends `Core`) + `PlatformTests`, `.iOS(.v16)`.

## Relevant Files & Context Pointers

- `Packages/Platform/Package.swift`, `Packages/Platform/Sources/Platform/{Navigation,Events}/*.swift`, `Packages/Platform/Tests/PlatformTests/**` — **NEW**
- `Tuist/Package.swift` — marker-region entry for `Packages/Platform`
- Source Spec §6 (full code), Changelog #7 (Core-only), §8

## Design Rationale

`tabPaths: [NavigationPath]` gives Android's `NestedNavigator` semantics on native iOS 16 APIs — each tab keeps its own back stack across tab switches. `AppEventBus` uses replay 0: lifecycle events are momentary; a consumer that missed one waits for the next. `AppRouter` keeps providers in a plain array (O(10) features max).

**Applicable skills:** none specific.

### BDD Scenarios

```gherkin
# Happy path
Scenario: navigate(to: SettingsRoot(), inTab: 2) appends to tabPaths[2] only
Scenario: destination(for:) returns the AnyView from the first provider whose canHandle is true

# Boundary / equivalence
Scenario: AppRouter(tabCount: 3, initialTab: 2) starts with 3 empty paths and selectedTab 2
Scenario: pop(inTab:) on an empty path is a no-op (no crash)
Scenario: popToRoot(inTab: 1) empties tabPaths[1] and leaves the others untouched
Scenario: destination(for:) with no matching provider returns an EmptyView-equivalent

# State transitions — per-tab isolation
Scenario: navigate twice in tab 0, switch to tab 1, navigate once -> tab 0 depth 2, tab 1 depth 1
Scenario: switchTab(1) then switchTab(0) preserves both tabs' stacks
Scenario: re-selecting the active tab via popToRoot(inTab: selectedTab) clears only that tab

# Async / race
Scenario: 10 rapid navigate() calls on tabPaths[0] leave depth exactly 10, order preserved
Scenario: publish() from a background thread is delivered on the bus without crash

# Event bus
Scenario: publish(A) then on(A.self) subscriber receives it; on(B.self) subscriber receives nothing (type filter)
Scenario: two subscribers on the same type both receive one publish
Scenario: a subscriber that subscribes AFTER publish receives nothing (replay 0)
Scenario: cancelling the AnyCancellable stops further delivery
Scenario: rapid publish(A),publish(B),publish(A) delivered to on(A.self) in order [A, A]

# Resource teardown
Scenario: dropping all AnyCancellables leaves the bus with no retained subscribers
```

### TDD Tests

- `AppRouterTests` — construction; `navigate/pop/popToRoot/switchTab` per-tab isolation matrix (the transition scenarios); rapid navigate order; `destination(for:)` provider resolution + no-match.
- `AppEventBusTests` — type filtering; multi-subscriber; late subscriber gets nothing; cancel stops delivery; ordering of rapid publishes; background-thread publish (`DispatchQueue.global().async`).
- `RouteProviderTests` — a `MockRouteProvider` returns true only for its route; `destination(for:)` returns its view.
- `@MainActor` for router tests; Combine assertions via a `record()` sink helper.

### RED → GREEN

- RED: per-tab isolation tests fail hard if `AppRouter` uses a single shared `NavigationPath` (the v1 design) — final depths would be wrong.
- GREEN: implement `tabPaths` array indexing + the event bus.

## Definition of Done

- `swift test --package-path Packages/Platform` green; every scenario has a passing test.
- Per-tab path isolation proven (navigate in one tab never mutates another).
- Event-bus type filtering + replay-0 + cancellation proven.
- `Package.swift` deps == `[Core]` (verified — no `Framework`). Coverage ≥ 80%. SwiftLint/SwiftFormat clean.

## Dependencies & Blockers

- Blocked by [Task 4](task_4_ios_core_package.md).
- Blocks [Task 10](task_10_ios_shell.md), [Task 11](task_11_ios_settings_feature.md), [Task 12](task_12_ios_scanner_and_composition.md).

## References & Rollback

- Source Spec §6, §8, Changelog #7.
- Rollback: remove `Packages/Platform/` + marker line.
