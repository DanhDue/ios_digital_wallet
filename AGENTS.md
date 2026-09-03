# AGENTS.md — iOS Super App Template — Project Context

## Project overview

A **governed multi-package native iOS template**: Clean Architecture + MVI +
Feature-First, SwiftUI, a Host/Shell composition root, and an AST-based
architecture gate (`ArchTests`). Strong focus on module boundaries, manual
constructor-injection DI, and one declarative source of truth for the project
graph (Tuist). The authoritative architecture reference is
**`docs/architecture/ARCHITECTURE.md`** (written in Task 9).

## Project structure

One local SPM package per module; the SPM dependency graph is the primary
boundary mechanism — a package that does not declare a dependency cannot import
it.

- **`App/`** — thin host target: `@main`, DI wiring, `RouteProvider`
  registration, lifecycle events. No business logic.
- **`Packages/Shell/`** — tab layout + one `NavigationStack` (and its own path)
  per tab. **Feature-blind**: depends on `Platform`, `Framework`, `AppUIKit`,
  never on a feature. `HomeStubView` lives here, not in a feature.
- **`Packages/Core/`** — the dependency floor: framework-agnostic primitives,
  protocols, extensions. Swift stdlib only; **no package dependencies**.
- **`Packages/Framework/`** — `MviViewModel` / `MvvmViewModel` / `ViewState`.
  Depends on `Core`.
- **`Packages/Network/`** — `APIClient`, interceptors, `Environment`; a 401 is
  surfaced as an event via a `Core` protocol. Depends on `Core` only.
- **`Packages/AppUIKit/`** — shared design system + components. Depends on
  `Core` only (**not** `Framework`).
- **`Packages/Platform/`** — the cross-feature seam: `AppRoute` / `AppRoutes`,
  `RouteProvider`, `AppRouter`, `AppEventBus`. Depends on `Core` only.
- **`Packages/Features/*`** — one feature each, with `Data` / `Domain` /
  `Presentation`. Ships `SettingsFeature` (a real reference feature) and
  `ScannerFeature` (a stub). Depend only on the infrastructure packages —
  **never on another feature**.
- **`ArchTests/`** — standalone swift-syntax architecture gate (rules K1–K9).
  Never linked into the app. Run with `swift test --package-path ArchTests`.
- **`Tuist/`** — `Package.swift` (the SPM graph Tuist reads) and
  `ProjectDescriptionHelpers/Module.swift` (the shared target factory). The
  `// tuist:*:begin/end` marker regions are edited by Mason bricks — keep them
  verbatim.

## Tech stack

- **Language**: Swift 6 (toolchain from Xcode 16+; currently Swift 6.3.3).
- **Minimum OS**: iOS 16 (single, uniform floor).
- **UI**: SwiftUI.
- **State**: `ObservableObject` + Combine, via `Framework.MviViewModel`.
- **DI**: manual constructor injection, composed only in `App/`.
- **Project graph**: Tuist 4 (`Tuist.swift` / `Project.swift` / `Workspace.swift`
  / `Tuist/Package.swift`).
- **Architecture tests**: swift-syntax `602.0.0` (exact, toolchain-locked).
- **Quality**: SwiftLint `0.65.1`, SwiftFormat `0.63.0` (one config in
  `quality/`, invoked from the repo root).
- **CI**: GitHub Actions, `macos-15`, no signing secrets.

## Build & configuration

- **`.mise.toml`** pins Tuist / SwiftLint / SwiftFormat. `mise install` fetches
  those exact versions; CI does the same.
- **`Module.swift`** is the single place the iOS deployment target and the
  shared target/package factory live. Do not redefine deployment targets
  per-target.
- **`.xcodeproj` / `.xcworkspace` are generated** by `tuist generate` and are
  git-ignored. Never hand-edit a `.pbxproj`; change the manifests instead.
- Add a package to the graph through `Tuist/Package.swift` +
  `Project.swift` / `Workspace.swift` marker regions, then `tuist generate`.

## Coding guidelines for agents

1. **Respect the dependency graph.** A feature imports infrastructure only,
   never another feature. Cross-feature traffic goes through `Platform`
   (`AppRoutes` / `AppEventBus`). `ArchTests` (K1–K9) + `check_module_boundaries.sh`
   enforce this.
2. **Domain is pure Swift** — no `import SwiftUI` / `UIKit` / `Combine` under
   any `Sources/*/Domain/`.
3. **Data types stay `internal`** — expose behaviour through `Domain` protocols.
4. **Naming**: `*Action` / `*State` / `*Event` / `*ViewModel` (`: MviViewModel`)
   / `*UseCase` / `*View` (`: View`) / `*Repository` (protocol, Domain) /
   `*RepositoryImpl` (Data) / `*RouteProvider` (`: RouteProvider`).
5. **One commit per task.** Do not bundle unrelated changes. The generated Xcode
   project is never part of a commit.
6. **No product domain in the template** — no "wallet"/payments concepts in
   shared code; features are illustrative only.
7. **Keep `ArchTests/` lint-clean and format-clean** — its `Sources/` and
   `Tests/` are in the lint scope.
