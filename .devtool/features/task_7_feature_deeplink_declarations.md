---
id: "task_7_feature_deeplink_declarations"
status: "done"
priority: "high"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T20:17:26+07:00"
completedAt: "2026-09-10T20:17:26+07:00"
labels: ["feature", "deeplink", "settings", "scanner"]
order: "a7"
---

# Task 7: Feature Deep-Link Declarations & Standalone Tests

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

Each feature declares its own URL contract on its own `RouteProvider`. This is
the task that proves invariant **R2** — a feature owns its deep links and can
test them with no app and no Tuist present.

**The template map (Source Spec §4.11):**

| Pattern | Stack | `requiresAuth` | Demonstrates |
|---|---|---|---|
| `/settings` | `[AppRoutes.SettingsRoot()]` | `false` | tab switch onto a tab root — first element dropped, no duplicated screen |
| `/scanner` | `[AppRoutes.ScannerRoot()]` | `false` | the second tab root |
| `/scanner/result/:code` | `[AppRoutes.ScannerRoot(), ScannerResultRoute(code:)]` | `false` | multi-level stack **and** a path parameter |

```swift
// Features/Scanner/…/ScannerRouteProvider.swift
public var deepLinks: [DeepLinkRoute] {
    [
        DeepLinkRoute("/scanner") { _ in [AppRoutes.ScannerRoot()] },
        DeepLinkRoute("/scanner/result/:code") { params in
            [AppRoutes.ScannerRoot(), ScannerResultRoute(code: params["code"] ?? "")]
        },
    ]
}
```

**No shipped route sets `requiresAuth: true`.** The template has no
authentication feature; gating a link would deny the template's own demo link on
a fresh clone, and inventing an auth feature would violate the standing "no
product domain in the template" rule. The flag's behaviour is covered by
[Task 5](task_5_deeplink_router_engine.md) with a fake guard and
[Task 9](task_9_tier_c_acceptance_suite.md) with a test-injected guard.

**Missing-parameter policy:** a pattern that declares `:code` cannot match a link
without that segment, so `params["code"]` is always present when `build` runs.
The `?? ""` is defensive only; a test pins that the captured value reaches the
route unmodified.

## Relevant Files & Context Pointers

- `Features/Scanner/Sources/Scanner/Presentation/ScannerRouteProvider.swift` — add `deepLinks`. This same file also declares `ScannerResultRoute` (from [Task 6](task_6_scanner_result_subfeature.md)); the route is **not** in a file of its own
- `Features/Settings/Sources/Settings/Presentation/SettingsRouteProvider.swift` — add `deepLinks`
- `Features/Scanner/Tests/ScannerTests/ScannerDeepLinkTests.swift` — **new**
- `Features/Settings/Tests/SettingsTests/SettingsDeepLinkTests.swift` — **new**
- `Packages/Platform/Sources/Platform/Navigation/AppRoutes.swift` — the shared route values referenced

## Design Rationale

- **The declaration lives next to the provider it belongs to.** A reader opening
  `ScannerRouteProvider` sees both how Scanner renders and how Scanner is
  addressed. Nothing in `App` or `Platform` restates it.
- **The first element of a stack is the tab root, by convention.** The router's
  `isTabRoot` de-duplication depends on `build` returning the parent chain
  starting at the feature's entry route — a convention this task establishes and
  [Task 14](task_14_deeplink_docs.md) documents.
- **Tests run inside the feature package.** `swift test --package-path
  Features/Scanner` must exercise these without the app target, which is what
  makes criterion 4.1 (sandbox development) survive this epic instead of
  regressing.
- Applicable skill in `.agents/skills/`: **`test-driven-development`**.

## TDD Checklist

- [ ] **RED**: `ScannerDeepLinkTests` — `/scanner` matches and builds
      `[ScannerRoot]` · `/scanner/result/ABC123` matches and builds
      `[ScannerRoot, ScannerResultRoute(code: "ABC123")]` in that order ·
      `/scanner/result` (missing segment) does **not** match ·
      `/scanner/result/ABC123/extra` does not match · `requiresAuth` is `false`
      on both.
- [ ] **RED**: `SettingsDeepLinkTests` — `/settings` matches and builds
      `[SettingsRoot]` · `/settings/unknown` does not match · exactly one route
      is declared.
- [ ] **GREEN**: add the `deepLinks` properties to both providers.
- [ ] **REFACTOR**: confirm neither feature imports the other and neither names a
      pattern belonging to the other; doc-comment the parent-chain convention.

## Definition of Done

- [ ] `swift test --package-path Features/Scanner` passes **with no app target
      and no `tuist generate`**.
- [ ] `swift test --package-path Features/Settings` passes under the same
      condition.
- [ ] `swift test --package-path ArchTests` passes — **K1** (no feature→feature
      dependency) and **K9** still green.
- [ ] Captured path parameters reach the built route unmodified, including case.
- [ ] SwiftLint `--strict` and SwiftFormat `--lint` clean.

## Dependencies & Blockers

- Blocked by [Task 4](task_4_deeplink_route_provider_seam.md) — needs
  `RouteProvider.deepLinks` and `DeepLinkRoute`.
- Blocked by [Task 6](task_6_scanner_result_subfeature.md) — needs
  `ScannerResultRoute`.
- Blocks [Task 9](task_9_tier_c_acceptance_suite.md) and
  [Task 10](task_10_archtests_k10.md) (K10.2 needs real declarations to check).

## References & Rollback

- BDD scenarios captured at implementation time: [task-7-feature-deeplink-declarations.md](../epic/ios_deeplink_router/bdd/task-7-feature-deeplink-declarations.md)
- Source Spec §4.11 (template deep-link map), §10 Tier A per-feature section.
- `.devtool/epic/ios_super_app_template/2026-09-02-ios-super-app-template-design.md`
  §8 — the cross-feature communication table these declarations extend.
- **Rollback**: delete the `deepLinks` property from each provider; the protocol
  default returns `[]` and both features fall back to being unaddressable
  without any other change.
