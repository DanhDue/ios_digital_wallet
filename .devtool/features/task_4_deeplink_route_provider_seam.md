---
id: "task_4_deeplink_route_provider_seam"
status: "todo"
priority: "high"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T03:42:16+07:00"
completedAt: null
labels: ["platform", "deeplink", "public-api"]
order: "a4"
---

# Task 4: DeepLinkRoute & RouteProvider.deepLinks Seam

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

Add the unit a feature declares, and the protocol requirement through which it
reaches the router. This is a **public API change to `RouteProvider`**, so it is
isolated in its own task.

```swift
public struct DeepLinkRoute {
    public let pattern: DeepLinkPattern
    public let requiresAuth: Bool
    public let build: @MainActor (DeepLinkParams) -> [any AppRoute]

    public init(
        _ pattern: String,
        requiresAuth: Bool = false,
        build: @escaping @MainActor (DeepLinkParams) -> [any AppRoute]
    )
}

public protocol RouteProvider {
    func canHandle(_ route: any AppRoute) -> Bool
    @ViewBuilder func destination(for route: any AppRoute) -> AnyView
    @MainActor var deepLinks: [DeepLinkRoute] { get }
}

public extension RouteProvider {
    @MainActor var deepLinks: [DeepLinkRoute] { [] }
}
```

Two properties matter and must be pinned by tests:

1. **`build` returns an array** — the parent-to-child stack. This is what solves
   blocker **D6** (multi-level stack construction) and is why back navigation
   from a deep-linked child lands on its parent rather than outside the app.
2. **The default implementation returns `[]`** — every shipped `RouteProvider`
   keeps compiling untouched. Enforcement that cross-feature routes actually
   declare a pattern comes later, from ArchTests **K10.2**, not from the compiler.

## Relevant Files & Context Pointers

- `Packages/Platform/Sources/Platform/Navigation/DeepLink/DeepLinkRoute.swift` — **new**
- `Packages/Platform/Sources/Platform/Navigation/RouteProvider.swift` — add the requirement + default extension
- `Packages/Platform/Tests/PlatformTests/RouteProviderTests.swift` — existing suite, extend
- `Features/Settings/Sources/Settings/Presentation/SettingsRouteProvider.swift` — must keep compiling unchanged
- `Features/Scanner/Sources/Scanner/Presentation/ScannerRouteProvider.swift` — must keep compiling unchanged

## Design Rationale

- **`@MainActor` closure, not `@Sendable`.** This mirrors the existing
  `makeViewModel: @MainActor () -> ViewModel` convention in every shipped
  `RouteProvider`, and it means `protocol AppRoute` does **not** have to gain a
  `Sendable` conformance — a change that would ripple into every feature. The
  table is built and read exclusively on the main actor, so nothing is lost.
- **`DeepLinkRoute` is deliberately not `Sendable`.** Making it `Sendable` would
  force the `AppRoute` conformance change above for no benefit.
- **Default implementation over a separate protocol.** A `DeepLinkProviding`
  side-protocol would let a provider silently not adopt it and would give the
  router two registration paths. One protocol with a default keeps registration
  uniform: the router calls `register(_:)` once and reads `deepLinks`.
- **`requiresAuth` is a `Bool` on the route, not a type.** The feature states a
  requirement; the host decides what satisfies it (see
  [Task 5](task_5_deeplink_router_engine.md)). That split is what keeps
  `Platform` ignorant of authentication (invariant **R1**).
- Applicable skill in `.agents/skills/`: **`test-driven-development`**.

## TDD Checklist

- [ ] **RED**: `DeepLinkRoute` holds the parsed pattern, the `requiresAuth` flag
      (defaulting to `false`), and a `build` closure whose array result is
      returned in declaration order.
- [ ] **RED**: extend `RouteProviderTests` — a provider that declares nothing
      returns `[]` from `deepLinks`; a provider that declares two routes returns
      both, in order.
- [ ] **GREEN**: add `DeepLinkRoute` and the protocol requirement + default
      extension.
- [ ] **REFACTOR**: doc-comment why the closure is `@MainActor` rather than
      `@Sendable`, so the next reader does not "fix" it.

## Definition of Done

- [ ] `swift test --package-path Packages/Platform` passes.
- [ ] `swift test --package-path Features/Settings` and
      `swift test --package-path Features/Scanner` pass **with no source change
      in either feature** — proving the default keeps existing providers valid.
- [ ] `protocol AppRoute` is unchanged (no `Sendable` conformance added).
- [ ] `swift test --package-path ArchTests` passes — **K5** still accepts both
      shipped `RouteProvider` conformances.
- [ ] SwiftLint `--strict` and SwiftFormat `--lint` clean.

## Dependencies & Blockers

- Blocked by [Task 3](task_3_deeplink_pattern_matching.md) — `DeepLinkRoute`
  stores a `DeepLinkPattern`.
- Blocks [Task 5](task_5_deeplink_router_engine.md),
  [Task 7](task_7_feature_deeplink_declarations.md) and
  [Task 11](task_11_mason_brick_deeplinks.md).

## References & Rollback

- Source Spec §4.3 (`DeepLinkRoute`), §4.4 (`RouteProvider` extension).
- Existing convention: `SettingsRouteProvider.makeViewModel: @MainActor () -> …`.
- **Rollback**: the protocol requirement has a default implementation, so
  reverting it cannot break a feature that never adopted it. Delete
  `DeepLinkRoute.swift` and the requirement + extension.
