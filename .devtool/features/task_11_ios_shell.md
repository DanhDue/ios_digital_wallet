---
id: "task_11_ios_shell"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["architecture", "shell", "mvi"]
order: "a11"
---

# Task 11: Implement ShellView + ShellViewModel + HomeStubView

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Implement the Host Shell — the tab container. Equivalent to Android's `:shell` module and Flutter's `lib/shell/`. The Shell is NOT a Feature; it lives in the app target.

**Files to create**:

```
iOSDigitalWallet/Shell/
├── ShellView.swift           ← TabView with 3 tabs; consumes AppRouter + RouteProviders
├── ShellViewModel.swift      ← MviViewModel<ShellState, ShellAction, ShellEvent>
├── ShellState.swift          ← struct ShellState { var selectedTab: Int = 2 } (default = settings)
├── ShellAction.swift         ← enum ShellAction { case selectTab(Int), popToRootTab(Int) }
├── ShellEvent.swift          ← enum ShellEvent { case scrollToTop } (for tab re-tap behavior)
└── Tabs/
    └── HomeStubView.swift    ← simple stub: icon + "Home" text, no logic
```

**ShellView** wraps `TabView` with 3 tabs:
- Tab 0 (index 0): Home → `HomeStubView`
- Tab 1 (index 1): Scanner → `ScannerRouteProvider.rootView()` (from registered providers)
- Tab 2 (index 2): Settings → `SettingsRouteProvider.rootView()` (from registered providers)

**ShellViewModel** (MVI):
- `selectTab(Int)` action → update `selectedTab` state + publish `ShellTabVisibilityChanged` event via `AppEventBus`
- Re-tap active tab → emit `scrollToTop` event (shell-level behavior, not feature-level)

**iOSDigitalWalletApp.swift** update: inject `ShellView` as the root view; create and register `RouteProvider` instances; pass `AppRouter` as `@StateObject`.

## Relevant Files & Context Pointers

- `iOSDigitalWallet/Shell/ShellView.swift` — **NEW**
- `iOSDigitalWallet/Shell/ShellViewModel.swift` — **NEW**
- `iOSDigitalWallet/Shell/ShellState.swift` — **NEW**
- `iOSDigitalWallet/Shell/ShellAction.swift` — **NEW**
- `iOSDigitalWallet/Shell/ShellEvent.swift` — **NEW**
- `iOSDigitalWallet/Shell/Tabs/HomeStubView.swift` — **NEW**
- `iOSDigitalWallet/App/iOSDigitalWalletApp.swift` — update root view + DI wiring
- Reference: `bloc_digital_wallet/lib/shell/shell_page.dart` + `shell_bloc.dart` (Flutter — mirror)
- Reference: Android `:shell` Task 10 (`ShellViewModel`, `ShellScreen`, `HomeStubPage`)
- Source spec §3 (G3: Shell is pure container), §8 (ShellTabVisibilityChanged event)

## Design Rationale

Default selected tab = 2 (Settings) — matching Flutter and Android template convention. Settings is the most fully implemented tab in the template, so new developers cloning immediately see a working Feature.

`ShellViewModel` inherits from `MviViewModel<ShellState, ShellAction, ShellEvent>` — enforcing MVI even for the host shell. This is consistent with Android's `ShellViewModel : MviViewModel` and demonstrates the pattern for anyone reading the template.

`RouteProvider` instances are created in `iOSDigitalWalletApp.swift` and injected into `AppRouter` — the DI root. Features don't self-register; the host wires them. This mirrors Android's Hilt `@IntoSet` aggregation (the host collects, features don't know about each other).

## TDD Checklist

- [ ] **RED**: `ShellViewModelTests` — `dispatch(.selectTab(0))` updates `selectedTab` to 0; `dispatch(.selectTab(2))` updates to 2; re-dispatching same tab emits `scrollToTop` event via `eventSubject`.
- [ ] **RED**: `ShellTabVisibilityChangedTests` — `dispatch(.selectTab(1))` triggers `AppEventBus.shared.publish(ShellTabVisibilityChanged(tabIndex: 1, isVisible: true))`.
- [ ] **GREEN**: Implement `ShellViewModel`, `ShellState`, `ShellAction`, `ShellEvent`, `ShellView`, `HomeStubView`.
- [ ] **INTEGRATE**: Update `iOSDigitalWalletApp.swift` — `ShellView()` is root; `AppRouter` registered as `@StateObject`; `RouteProvider`s registered (empty for now — Tasks 12 provides real implementations).
- [ ] **VERIFY**: `xcodebuild build` green; app launches showing 3-tab Shell with HomeStubView on tab 0.

## Definition of Done

- App launches with 3-tab Shell. Default tab = Settings (index 2).
- Tab selection updates `ShellViewModel.uiState.selectedTab`.
- `ShellTabVisibilityChanged` published on tab switch (verified by unit test).
- `HomeStubView` renders in tab 0 (visual check).
- SwiftLint + SwiftFormat clean on all new files.

## Dependencies & Blockers

- Blocked by [Task 10](task_10_ios_app_structure.md) (folder structure must exist).
- Blocked by [Task 5](task_5_ios_framework_package.md) (`MviViewModel`), [Task 7](task_7_ios_appuikit_package.md) (`AppUIKit`), [Task 8](task_8_ios_platform_package.md) (`AppRouter`, `AppEventBus`).
- Blocks [Task 12](task_12_ios_features_and_routing.md) (Shell needs `RouteProvider` implementations from Features).

## References & Rollback

- Source spec §4.1 (Shell structure), §8 (lifecycle events), §3 G3 (Shell as pure container).
- Rollback: delete `Shell/` folder from Xcode + filesystem; revert `iOSDigitalWalletApp.swift`. App reverts to placeholder.
