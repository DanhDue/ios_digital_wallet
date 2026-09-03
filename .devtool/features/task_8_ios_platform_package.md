---
id: "task_8_ios_platform_package"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["architecture", "spm", "navigation", "events"]
order: "a8"
---

# Task 8: Create `Platform` SPM local package (AppRouter + AppEventBus)

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Create `Sources/Platform/` — the cross-feature seam. Depends on `Core` + `Framework`. Contains:

**Navigation**:
- `AppRoute` protocol (`Hashable`)
- `AppRoutes` enum — shared route structs (`SettingsRoute`, `ScannerRoute`)
- `RouteProvider` protocol — Features implement this to register their screens with Shell (equivalent to Android's `EntryProviderInstaller`)
- `AppRouter: ObservableObject` — wraps `NavigationPath` (iOS 16+), holds registered `RouteProvider` array, exposes `navigate(to:)`, `pop()`, `popToRoot()`, `view(for:)`

**Events**:
- `AppEvent` protocol — base for all lifecycle events
- Minimum vocabulary: `ShellTabVisibilityChanged`, `AppLifecycleChanged`, `UserLoggedOut`
- `AppEventBus` — singleton, `PassthroughSubject<any AppEvent, Never>`, exposes `publish(_:)` and `on<T>(_:) -> AnyPublisher<T, Never>`

**Note on NavigationPath**: requires iOS 16+. This is a documented gap — `Core`/`Framework`/business logic remain iOS 13+; the navigation layer accepts iOS 16+ floor. Document this split in `ARCHITECTURE.md` (Task 9).

`Package.swift`: depends on `Core` (local) + `Framework` (local). No external dependencies.

## Relevant Files & Context Pointers

- `Sources/Platform/Package.swift` — **NEW**
- `Sources/Platform/Sources/Platform/Navigation/AppRoute.swift` — **NEW**
- `Sources/Platform/Sources/Platform/Navigation/AppRoutes.swift` — **NEW**
- `Sources/Platform/Sources/Platform/Navigation/RouteProvider.swift` — **NEW**
- `Sources/Platform/Sources/Platform/Navigation/AppRouter.swift` — **NEW**
- `Sources/Platform/Sources/Platform/Events/AppEvent.swift` — **NEW**
- `Sources/Platform/Sources/Platform/Events/AppEventBus.swift` — **NEW**
- `Sources/Platform/Tests/PlatformTests/` — **NEW**
- `iOSDigitalWallet.xcodeproj` — add `Platform` package reference
- Reference: source spec §6 (full Platform code)
- Reference: Android `:platform` in `.devtool/epic/android_super_app_template/` Task 1

## Design Rationale

`AppEventBus` uses `replay = 0` (no replay) matching Android's `MutableSharedFlow(replay = 0, extraBufferCapacity = 64)`. Events published before any subscriber are dropped — fire-and-forget broadcast. This is intentional: lifecycle events (tab visibility, app foreground) are momentary and consumers that miss them should wait for the next one.

`AppRouter` holds providers as a simple array because the number of registered features is small (3 in template, O(10) in real apps). A `Dictionary<AnyHashable, RouteProvider>` lookup is unnecessary optimization.

## TDD Checklist

- [ ] **RED**: `AppEventBusTests` — `publish` then `on(type:)` delivers only matching type; two subscribers both receive; publish with no subscriber does not crash. Use `XCTestExpectation` or Combine sink.
- [ ] **RED**: `AppRouterTests` — `navigate(to:)` appends to `path`; `pop()` removes last; `popToRoot()` empties path; `view(for:)` returns nil for unregistered route.
- [ ] **RED**: `RouteProviderTests` — mock `RouteProvider` returns `true` for its own route, `false` for unknown.
- [ ] **GREEN**: Implement all Platform types.
- [ ] **REFACTOR**: KDoc all public API. SwiftLint + SwiftFormat clean.

## Definition of Done

- `Sources/Platform/` builds. Unit tests green. App imports `Platform` without error.
- `AppEventBus.shared.publish()` / `on()` verified end-to-end in test.
- `AppRouter.register()` + `view(for:)` resolution verified.
- SwiftLint + SwiftFormat clean. Coverage ≥ 80%.

## Dependencies & Blockers

- Blocked by [Task 4](task_4_ios_core_package.md) and [Task 5](task_5_ios_framework_package.md).
- Blocks [Task 9](task_9_ios_rewire_arch_doc.md), [Task 11](task_11_ios_shell.md), [Task 12](task_12_ios_features_and_routing.md).

## References & Rollback

- Source spec §6 (full Platform code + NavigationPath iOS 16 gap note).
- Rollback: remove `Sources/Platform/` + package reference.
