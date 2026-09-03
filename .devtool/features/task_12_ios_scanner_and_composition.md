---
id: "task_12_ios_scanner_and_composition"
status: "todo"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: null
labels: ["architecture", "spm", "feature", "composition", "governance"]
order: "a12"
---

# Task 12: `ScannerFeature` stub + App composition root + enable ArchTests K1/K6/K9

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: A + C.** Tier A for the composition-root behavior, Tier C for the end-to-end navigation flow (Source Spec §4.3). Closes Phase 2.

## Requirement Analysis

**1. `ScannerFeature` package** (`Packages/Features/ScannerFeature/`) — depends on `Platform`, `Framework`, `AppUIKit`. Full scaffold, no logic — the shape a `mason make` output should match.
- `Domain/` — `ScannerEntity`, `ScannerRepository` protocol, `GetScannerDataUseCase` (returns `.loading` stub).
- `Data/` — `ScannerRepositoryImpl` returning a fixed stub (internal).
- `Presentation/` — `ScannerAction`/`State`/`Event` (minimal), `ScannerViewModel : MviViewModel`, `ScannerView` = `AppEmptyStateView(title: "Scanner coming soon")`, `ScannerRouteProvider` (canHandle `AppRoutes.ScannerRoot()`).

**2. App composition root** (`App/Sources/Composition/`):
- `AppComposition.swift` — builds the `AppRouter` (`tabCount: 3, initialTab: 2`) + `AppEventBus`; constructs each Feature's dependencies (constructor injection) and `RouteProvider`; `appRouter.register(SettingsRouteProvider(...))` / `register(ScannerRouteProvider(...))` inside `// app:route-providers:begin/end`. Imports `SettingsFeature` + `ScannerFeature` + `Shell` (App is the sole aggregator).
- `NetworkComposition.swift` — builds `URLSessionAPIClient` with an `AuthEventSink` whose `onUnauthorized()` calls `AppEventBus.shared.publish(UserLoggedOut())`.
- `LifecycleObserver.swift` — observes SwiftUI `ScenePhase`; publishes `AppLifecycleChanged(.foreground/.background/.inactive)`.
- `RootView.swift` — hosts `ShellView(router:)` from the composition.
- `Project.swift` — app-target deps add `Shell`, `SettingsFeature`, `ScannerFeature` inside `// tuist:app-deps:begin/end`.

**3. Enable ArchTests K1 / K6 / K9:**
- **K1** — no Feature `Package.swift` depends on another Feature package; `check_module_boundaries.sh` clean; whitelist empty.
- **K6** — only the App target depends on >1 Feature; `Shell/Package.swift` depends on 0 Features.
- **K9** — any `AppRoute`-conforming type referenced from >1 Feature must be declared in `Platform/AppRoutes` (Settings/Scanner roots already are).

## Relevant Files & Context Pointers

- `Packages/Features/ScannerFeature/**` — **NEW**
- `App/Sources/Composition/{AppComposition,NetworkComposition,LifecycleObserver}.swift`, `App/Sources/RootView.swift` — **NEW / modify**
- `App/Tests/AppTests/**` — **NEW** (integration tests for the §4.3 flow)
- `Tuist/Package.swift`, `Project.swift` (`// tuist:app-deps`, `// app:route-providers` regions) — modify
- `ArchTests/Tests/ArchTests/{BoundaryRulesTests,HostRulesTests,RouteLocationRulesTests}.swift` — implement K1/K6/K9
- Source Spec §4.3 (sequence), §8 (channels), §6.2, Changelog #6, #8

## Design Rationale

The composition root is the one place features are named — this is the deliberate trade for having no DI framework (Non-Goal). `Shell` stays feature-blind; K6 enforces that structurally. Wiring `AuthEventSink` here (not in `Network`) keeps `Network` a leaf on `Core` (Changelog #8). `LifecycleObserver` in `App` is the natural owner of `ScenePhase`.

**Applicable skills:** none specific.

### BDD Scenarios (Tier A — composition behavior)

```gherkin
Scenario: composition registers exactly two route providers
  When AppComposition builds
  Then appRouter has providers for AppRoutes.SettingsRoot() and AppRoutes.ScannerRoot()

Scenario: 401 from the API client publishes UserLoggedOut exactly once
  Given the composed URLSessionAPIClient and a bus recorder
  When a stubbed request returns 401
  Then the bus received exactly one UserLoggedOut

Scenario: ScenePhase background -> AppLifecycleChanged(.background) published; foreground -> (.foreground)
Scenario: rapid foreground/background/foreground -> events published in that exact order

Scenario: ScannerViewModel.dispatch on the stub does not crash and keeps viewState .content/.loading as designed
Scenario: ScannerRouteProvider.canHandle is true only for AppRoutes.ScannerRoot()
```

### End-to-End Scenarios (Tier C — Source Spec §4.3)

```gherkin
Scenario: tap Settings tab renders the real SettingsView
  Given the composed app hosted in a test host
  When the user selects tab 2
  Then ShellTabVisibilityChanged(2,true) is published
  And AppRouter.destination(for: SettingsRoot()) resolves SettingsRouteProvider
  And SettingsView is on screen inside tab 2's NavigationStack

Scenario: deep push then tab switch then back preserves the per-tab stack
  When navigate(to: someRoute, inTab: 2) then switchTab(0) then switchTab(2)
  Then tab 2 still shows the pushed screen (depth 1)

Scenario: full simulator smoke — 3 tabs
  When the app launches on iPhone 16 simulator
  Then Home stub, Scanner "coming soon", and real Settings are each reachable by tab
```

### Governance gate

```gherkin
Scenario: ArchTests K1/K6/K9 pass on the current tree with an empty baseline and empty whitelist
Scenario: K6 fails if Shell/Package.swift is given a Feature dependency (inject, run, revert)
Scenario: K1 fails if SettingsFeature/Package.swift is given a dep on ScannerFeature (inject, run, revert)
Scenario: check_module_boundaries.sh stays exit 0
```

### TDD Tests

- `AppCompositionTests` — provider registration; a `MockURLProtocol` 401 → one `UserLoggedOut` on a fresh bus.
- `LifecycleObserverTests` — feed `ScenePhase` values; assert ordered `AppLifecycleChanged` emissions.
- `ScannerFeatureTests` — provider `canHandle`; ViewModel stub doesn't crash; view builds.
- `AppTests/NavigationFlowTests` — host the composed `ShellView`; drive tab selection; assert the §4.3 chain; per-tab stack preservation.
- `ArchTests` K1/K6/K9 — RED→GREEN inside `ArchTests`; injected-violation checks per the governance scenarios.

## Definition of Done

- `swift test` green for `Packages/Features/ScannerFeature` and `App/Tests/AppTests`.
- `swift test --package-path ArchTests` green with K1–K9 all active; injected violations for K1/K6 proven to fail.
- `tuist generate && xcodebuild test` green; simulator smoke shows 3 working tabs (Home stub / Scanner stub / real Settings), default = Settings.
- `check_module_boundaries.sh` exit 0; whitelist empty.
- `Shell/Package.swift` has 0 Feature deps; only the App target aggregates Features.

## Dependencies & Blockers

- Blocked by [Task 10](task_10_ios_shell.md), [Task 11](task_11_ios_settings_feature.md).
- Blocks [Task 13](task_13_ios_mason_bricks.md), [Task 15](task_15_ios_acceptance_e2e.md).

## References & Rollback

- Source Spec §4.3, §6.2, §8, Changelog #6, #8.
- Rollback: revert the `Composition/` files + `Project.swift` deps + the K1/K6/K9 rule files; remove `Packages/Features/ScannerFeature/`. App reverts to Phase 1 placeholder + (if kept) Settings-only.
