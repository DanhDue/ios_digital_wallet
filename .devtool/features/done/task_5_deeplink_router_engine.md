---
id: "task_5_deeplink_router_engine"
status: "done"
priority: "high"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T14:53:04+07:00"
completedAt: "2026-09-10T14:53:04+07:00"
labels: ["platform", "deeplink", "navigation", "architecture"]
order: "a5"
---

# Task 5: DeepLinkRouter Engine, Guard/Tab Seams, Pending Replay

## Epic Reference
Epic: [ios_deeplink_router](../../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

The engine. It owns the pattern table, resolves a URL to a route stack, asks the
host whether the stack is allowed, decides which tab it lands in, drives
`AppRouter`, and stores a link that could not be opened yet.

```swift
@MainActor public protocol DeepLinkGuard {
    func evaluate(_ stack: [any AppRoute], requiresAuth: Bool) -> GuardDecision
}
public enum GuardDecision {
    case allow
    case redirect(to: [any AppRoute], retainPending: Bool)
    case deny
}

public struct TabPlacement: Equatable, Sendable {
    public let tab: Int
    public let isTabRoot: Bool
    public init(tab: Int, isTabRoot: Bool)
}
@MainActor public protocol TabResolver {
    /// `nil` ⇒ no opinion; the router uses the currently selected tab.
    func placement(for route: any AppRoute) -> TabPlacement?
}

@MainActor public final class DeepLinkRouter {
    public init(
        router: AppRouter,
        guard: (any DeepLinkGuard)? = nil,
        tabResolver: (any TabResolver)? = nil,
        logger: (any Core.Logger)? = nil
    )
    public func register(_ provider: any RouteProvider)
    @discardableResult public func open(_ url: URL) -> DeepLinkOutcome
    public func drainPending()
}

public enum DeepLinkOutcome: Equatable { case opened, pendingGuard, denied, unmatched }
```

**Navigation algorithm for `.allow`:**

```swift
var stack = resolvedStack
let placement = tabResolver?.placement(for: stack[0])

// A tab is usable only if it indexes into `tabPaths`. Every AppRouter mutator
// silently no-ops on a bad index, so an unusable tab would return `.opened`
// having moved nothing. `selectedTab` is validated too: AppRouter.init does not
// clamp `initialTab`, so the current tab can itself be out of range.
func usable(_ candidate: Int?) -> Int? {
    guard let candidate, router.tabPaths.indices.contains(candidate) else { return nil }
    return candidate
}

guard let tab = usable(placement?.tab) ?? usable(router.selectedTab) else {
    log("no usable tab"); return .denied      // degenerate router; never silently .opened
}

// `isTabRoot` is a claim about ONE tab. If that tab was rejected, the claim is
// rejected with it — otherwise we would drop a route that is not the root of
// the tab we actually navigate to.
if placement?.isTabRoot == true, tab == placement?.tab { stack.removeFirst() }

router.switchTab(tab)
router.popToRoot(inTab: tab)
for route in stack { router.navigate(to: route, inTab: tab) }
```

**Three behaviours that are easy to get wrong and must be pinned by tests:**

1. **`isTabRoot` de-duplication.** `ShellView` renders tab roots via
   `router.destination(for: AppRoutes.…Root())`. Without dropping a leading
   route that *is* that tab's root, `/settings` would `popToRoot` (already
   showing Settings) and then push `SettingsRoot` again — the screen twice.
2. **Pending store holds exactly one link, no TTL.** A deep link means "go here
   now"; a newer link supersedes an older one. Cleared on success, on `.deny`,
   and on replacement.
3. **Redirect re-entrancy.** A guard that returns `.redirect` for its own
   redirect target loops forever. The router evaluates a redirect target
   **once**; anything other than `.allow` becomes `.denied` plus a log.

## Relevant Files & Context Pointers

- `Packages/Platform/Sources/Platform/Navigation/DeepLink/DeepLinkRouter.swift` — **new**
- `Packages/Platform/Sources/Platform/Navigation/DeepLink/DeepLinkGuard.swift` — **new** (`GuardDecision`)
- `Packages/Platform/Sources/Platform/Navigation/DeepLink/TabResolver.swift` — **new** (`TabPlacement`)
- `Packages/Platform/Sources/Platform/Navigation/AppRouter.swift` — driven, not modified
- `Packages/Core/Sources/Core/Logging/Logger.swift` — the logging seam
- `Packages/Platform/Tests/PlatformTests/DeepLinkRouterTests.swift` — **new**
- `Packages/Platform/Tests/PlatformTests/TestSupport.swift` — add fake guard / fake resolver

## Design Rationale

- **Synchronous `evaluate`.** `Core.SessionManaging.accessToken` is a
  synchronous, `NSLock`-guarded read, so the host's guard needs no `await`.
  Keeping `open(_:)` synchronous means the whole engine is testable without
  expectations or `async` test plumbing — a large simplicity win bought for free.
- **Both seams are optional (`nil`-able).** A consumer who gates nothing and has
  no tabs gets working deep links with zero configuration; `nil` guard means
  allow-all, `nil` resolver means "current tab".
- **`Platform` never learns "auth" or "tab layout" (invariant R1).** The guard
  receives a `Bool` the feature declared and a stack of opaque routes; the
  resolver answers a placement question. Neither protocol names a domain concept.
- **First match wins, registration order.** Same chain-of-responsibility contract
  as the existing `AppRouter.destination(for:)`. **K10.1** makes order
  irrelevant by forbidding duplicate patterns, but the rule is stated so
  behaviour stays defined if a duplicate is ever baselined.
- **`logger` is injected and optional.** `Platform` depends on `Core` only, and
  `Core.Logger` is already the project's logging seam.
- Applicable skills in `.agents/skills/`: **`test-driven-development`** (primary),
  **`systematic-debugging`** if pending/replay ordering misbehaves.

## TDD Checklist

- [ ] **RED**: resolution — first match wins · no pattern matches ⇒ `.unmatched` ·
      `build` returns `[]` ⇒ `.unmatched` · malformed URL ⇒ `.unmatched`.
- [ ] **RED**: navigation — `.allow` switches to the resolved tab, pops to root,
      then pushes in declaration order · `isTabRoot` drops the first element ·
      `placement` `nil` uses the current tab · an out-of-range tab falls back to
      the current tab and still navigates — never a silent no-op that returns
      `.opened` having done nothing.
- [ ] **RED**: gating — `.redirect(retainPending: true)` stores the pending link
      and pushes the redirect stack, returning `.pendingGuard` ·
      `.redirect(retainPending: false)` stores nothing · `.deny` returns
      `.denied` and clears any pending link.
- [ ] **RED**: pending — `drainPending()` replays to the correct tab and stack ·
      a second `open` replaces the stored link · `drainPending()` with an empty
      store is a no-op · a redirect target that does not evaluate to `.allow`
      yields `.denied` and does not recurse.
- [ ] **GREEN**: implement the three protocols and `DeepLinkRouter`.
- [ ] **REFACTOR**: extract the navigation algorithm into a named private method;
      confirm every failure path logs exactly once and mutates no router state.

## Definition of Done

- [ ] `swift test --package-path Packages/Platform` passes with every scenario
      above present.
- [ ] Equivalence partitions covered: guard absent / allow / redirect / deny;
      resolver absent / tab-root / non-root; pending empty / populated / replaced.
- [ ] **No failure path mutates `AppRouter`** — asserted by comparing
      `selectedTab` and every `tabPaths` count before and after.
- [ ] `Packages/Platform/Package.swift` gains no dependency beyond `Core`.
- [ ] `swift test --package-path ArchTests` passes — **K7** still green.
- [ ] SwiftLint `--strict` and SwiftFormat `--lint` clean.

## Dependencies & Blockers

- Blocked by [Task 2](task_2_deeplink_url_normalisation.md) — `open(_:)` normalises the URL before matching.
- Blocked by [Task 3](task_3_deeplink_pattern_matching.md) — resolution is pattern matching.
- Blocked by [Task 4](task_4_deeplink_route_provider_seam.md) — `register(_:)` reads `provider.deepLinks`.
- Blocks [Task 8](task_8_host_deeplink_wiring.md) and
  [Task 9](task_9_tier_c_acceptance_suite.md).

## References & Rollback

- BDD scenarios captured at implementation time: [task-5-deeplink-router-engine.md](../../epic/ios_deeplink_router/bdd/task-5-deeplink-router-engine.md)
- Source Spec §4.5 (seams), §4.6 (engine, navigation algorithm, pending,
  re-entrancy), §6 (error-handling matrix), §10 Tier A table.
- **Rollback**: nothing outside `Platform` references the engine until
  [Task 8](task_8_host_deeplink_wiring.md); deleting the new files is a clean
  revert. Once Task 8 lands, roll both back together.
