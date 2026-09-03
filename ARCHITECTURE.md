# Architecture

**The authoritative architecture guide is
[`docs/architecture/ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md).**
Read it for the layer rules, the MVI contract, the module map and 4-tier
dependency graph, cross-feature communication, the iOS stack rationale, code
examples, and the `ArchTests` K1–K9 governance table. This page is only a
one-paragraph orientation.

## Summary

This is a native-iOS super-app template built on **Clean Architecture + MVI +
Feature-First**. The dependency rule is `Presentation → Domain ← Data`, with a
pure-Swift `Domain` (no `SwiftUI` / `UIKit` / `Combine`). Every infrastructure
module, the `Shell`, and every feature is its **own local SPM package**, so the
compiler enforces module boundaries: a feature can only import infrastructure,
never another feature. Cross-feature traffic flows through `Platform`
(`AppRoutes` + `AppEventBus` + `RouteProvider`); the `App` target is a thin
composition root (manual constructor-injection DI, `RouteProvider` registration,
lifecycle events) and the `Shell` builds the tab layout with a per-tab
`NavigationStack` while staying feature-blind. The project graph is declared with
Tuist and generated on demand (`.xcodeproj` / `.xcworkspace` are not committed);
`ArchTests` (swift-syntax, rules K1–K9) plus
`scripts/check_module_boundaries.sh` and GitHub Actions CI keep the rules
honest.
