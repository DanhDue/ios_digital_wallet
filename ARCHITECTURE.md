# Architecture

The authoritative architecture guide lives at
**[`docs/architecture/ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md)**
(written in Task 9). This page is a pointer plus a one-paragraph summary.

## Summary

This is a native-iOS super-app template built on **Clean Architecture + MVI +
Feature-First**. The dependency rule is `Presentation → Domain ← Data`, with a
pure-Swift `Domain` (no `SwiftUI` / `UIKit` / `Combine`). Every infrastructure
module, the `Shell`, and every feature is its **own local SPM package**, so the
compiler enforces module boundaries: a feature can only import infrastructure,
never another feature. Cross-feature traffic flows through `Platform`
(`AppRoutes` + `AppEventBus`); the `App` target is a thin composition root
(manual constructor-injection DI, `RouteProvider` registration, lifecycle
events) and the `Shell` builds the tab layout with a per-tab `NavigationStack`
while staying feature-blind. The project graph is declared with Tuist and
generated on demand; `ArchTests` (swift-syntax, rules K1–K9) plus
`scripts/check_module_boundaries.sh` and GitHub Actions CI keep the rules
honest.

## Module set (Source Spec §4.1)

| Module | Package | Role |
|---|---|---|
| `App` | — (app target) | Thin host: `@main`, DI wiring, `RouteProvider` registration, lifecycle events. |
| `Shell` | `Packages/Shell` | Tab layout + per-tab `NavigationStack` (own path each). Feature-blind. `HomeStubView` lives here. |
| `Core` | `Packages/Core` | Dependency floor: framework-agnostic primitives, protocols, extensions. stdlib only, no package deps. |
| `Framework` | `Packages/Framework` | `MviViewModel` / `MvvmViewModel` / `ViewState`. → `Core`. |
| `Network` | `Packages/Network` | `APIClient`, interceptors, `Environment`; 401 → event via a `Core` protocol. → `Core`. |
| `AppUIKit` | `Packages/AppUIKit` | Shared design system + components. → `Core` (not `Framework`). |
| `Platform` | `Packages/Platform` | Cross-feature seam: `AppRoute` / `AppRoutes`, `RouteProvider`, `AppRouter`, `AppEventBus`. → `Core`. |
| `Features/*` | `Packages/Features/*` | One feature each (`Data` / `Domain` / `Presentation`). Ships `SettingsFeature` (real) + `ScannerFeature` (stub). Infra deps only — never another feature. |
| `ArchTests` | `ArchTests/` | Standalone swift-syntax architecture gate (K1–K9). Never linked into the app. |
