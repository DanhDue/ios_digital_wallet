---
id: "task_1_any_app_route_erasure"
status: "done"
priority: "high"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T09:32:54+07:00"
completedAt: "2026-09-10T09:32:54+07:00"
labels: ["architecture", "navigation", "platform", "shell", "breaking-change"]
order: "a1"
---

# Task 1: AnyAppRoute Erasure & Shell Destination Collapse

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

`SwiftUI.navigationDestination(for:)` matches on the **concrete** type of the
value held in a `NavigationPath`. `ShellView` therefore has to enumerate every
route type it can render, and today it names exactly two:

```swift
.navigationDestination(for: AppRoutes.SettingsRoot.self) { … }
.navigationDestination(for: AppRoutes.ScannerRoot.self)  { … }
```

Consequences (blocker **D3** in the Source Spec §1.3):

1. Any route outside those two — every feature-private child screen a deep link
   needs to reach — resolves to nothing and renders a blank screen.
2. Adding a route means editing `Packages/Shell`, which contradicts both the
   feature-blind contract (invariant **R3**) and the rule that scaffolding a
   feature never touches another module (**R5**).

This task erases the route type at the `NavigationPath` boundary so one
destination serves every route, present and future. It is the prerequisite for
the entire deep-link subsystem — a resolved deep link may target any route, so
until this lands there is nothing to navigate to.

**Deliverables**

1. `AnyAppRoute` — a `Hashable` box over `any AppRoute` in `Platform`.
2. `AppRouter.navigate(to:inTab:)` boxes before appending to `tabPaths`.
3. `ShellView.tabStack` collapses N destinations into one
   `.navigationDestination(for: AnyAppRoute.self)`.
4. The three existing suites that observe path contents or destination wiring
   are updated in this task, RED first.

**Compile-risk decision to settle here, not by argument:** `AnyHashable(wrapped)`
over an existential `any AppRoute` relies on implicit existential opening. If it
does not compile under Swift 6 strict concurrency, use the documented fallback —
store `AnyHashable` in the path directly and recover the route with
`base as? any AppRoute`. Behaviour is identical; record which one was used in the
type's doc comment.

## Relevant Files & Context Pointers

- `Packages/Platform/Sources/Platform/Navigation/AnyAppRoute.swift` — **new**
- `Packages/Platform/Sources/Platform/Navigation/AppRouter.swift` — `navigate(to:inTab:)`
- `Packages/Platform/Sources/Platform/Navigation/AppRoute.swift` — the protocol being erased (unchanged)
- `Packages/Shell/Sources/Shell/ShellView.swift` — `tabStack(index:root:)`
- `Packages/Platform/Tests/PlatformTests/AppRouterTests.swift` — asserts path contents
- `Packages/Platform/Tests/PlatformTests/AnyAppRouteTests.swift` — **new**
- `Packages/Shell/Tests/ShellTests/FeatureBlindRenderTests.swift` — asserts destination wiring
- `App/Tests/AppTests/NavigationFlowTests.swift` — Tier C navigation integration

## Design Rationale

- **Erasure at the boundary, not in the protocol.** `AppRoute` stays a bare
  `Hashable` marker; only the value stored in `NavigationPath` is boxed. Features
  keep declaring plain structs and never see `AnyAppRoute`.
- **`AppRouter.destination(for:)` is untouched.** It already takes
  `any AppRoute`; `ShellView` unwraps with `boxed.wrapped` at the call site.
- **Equality must not collapse distinct types.** Two different route types with
  identical stored values must compare unequal, otherwise `NavigationPath`
  deduplication and back navigation misbehave. `AnyHashable` gives this for free
  and the test suite pins it.
- Applicable skills in `.agents/skills/`: **`test-driven-development`** (this task
  is behaviour-changing and fully testable), **`systematic-debugging`** if the
  existential-opening compile issue appears.

## TDD Checklist

- [ ] **RED**: `AnyAppRouteTests` — same type + same value ⇒ equal and equal
      hashes; two distinct types with identical stored values ⇒ **not** equal;
      `wrapped` round-trips the original value.
- [ ] **RED**: update `AppRouterTests` to expect `AnyAppRoute` elements —
      `navigate` appends a boxed value, `pop` / `popToRoot` / out-of-range guards
      keep their current behaviour.
- [ ] **RED**: extend `FeatureBlindRenderTests` — a feature-private route (a test
      double conforming to `AppRoute`, declared in the test target) resolves
      through the single erased destination.
- [ ] **GREEN**: add `AnyAppRoute`, box inside `navigate(to:inTab:)`, collapse
      `ShellView.tabStack` to one destination.
- [ ] **GREEN**: repair `NavigationFlowTests` against the new element type.
- [ ] **REFACTOR**: doc-comment `AnyAppRoute` with the reason for erasure and
      which implementation variant was used; confirm no other call site reaches
      into `tabPaths` expecting a raw route.

## Definition of Done

- [ ] `swift test --package-path Packages/Platform` passes.
- [ ] `swift test --package-path Packages/Shell` passes.
- [ ] `swift test --package-path ArchTests` passes — **K6** still green
      (`Shell` names no feature module).
- [ ] `tuist generate --no-open && xcodebuild test` passes, including
      `NavigationFlowTests`.
- [ ] `ShellView` contains exactly **one** `.navigationDestination` per tab stack
      and names **zero** concrete route types.
- [ ] `swiftlint --strict --config quality/.swiftlint.yml` and
      `swiftformat --config quality/.swiftformat . --lint` are clean.
- [ ] Pushing a route that has no `AppRoutes` entry renders its view rather than
      a blank screen — demonstrated by a test, not by inspection.

## Dependencies & Blockers

- Blocks every other task in this epic — nothing can navigate to a resolved deep
  link until erasure lands.
- Blocked by: nothing.

## References & Rollback

- BDD scenarios captured at implementation time: [task-1-any-app-route-erasure.md](../epic/ios_deeplink_router/bdd/task-1-any-app-route-erasure.md)
- Source Spec §4.7 (`AnyAppRoute` and the `Shell` destination collapse), §1.3
  blocker **D3**.
- `docs/architecture/ARCHITECTURE.md` — navigation section, to be updated in
  [Task 14](task_14_deeplink_docs.md).
- **Rollback**: this task is a single self-contained commit touching `Platform`,
  `Shell` and three test suites. `git revert` restores the per-type destinations;
  no data, no persisted state and no public feature API is involved.
