# BDD Scenarios — Task 4: DeepLinkRoute & RouteProvider.deepLinks Seam

Captured from the implementer's QA pass at implementation time (2026-09-10).
Historical record of what was analysed — including partitions deliberately
excluded. The executable form is the XCTest suite; see the task's Relevant
Files. Task: [task_4_deeplink_route_provider_seam](../../../features/task_4_deeplink_route_provider_seam.md)

## Phase 1: BDD SCENARIOS

### BDD SCENARIOS

```gherkin
Feature: DeepLinkRoute construction

  Scenario: Pattern with leading slash
    Given the pattern string "/settings"
    When a DeepLinkRoute is constructed with it
    Then route.pattern equals DeepLinkPattern("/settings")

  Scenario: Pattern without leading slash is equivalent
    Given DeepLinkRoute("/settings") and DeepLinkRoute("settings")
    When their patterns are compared
    Then they are equal (mirrors Task 3's optional-leading-slash rule)

  Scenario: Root pattern has zero segments
    Given the pattern string "/"
    When a DeepLinkRoute is constructed with it
    Then route.pattern.segments is empty

  Scenario: Pattern with a parameter segment
    Given the pattern string "/tx/:id"
    When a DeepLinkRoute is constructed with it
    Then route.pattern.segments equals [.literal("tx"), .parameter("id")]

  Scenario: requiresAuth defaults to false
    Given a DeepLinkRoute constructed with no requiresAuth argument
    Then route.requiresAuth is false

  Scenario: requiresAuth explicit true is honored
    Given a DeepLinkRoute constructed with requiresAuth: true
    Then route.requiresAuth is true

  Scenario: requiresAuth explicit false is honored (equivalence boundary vs. default)
    Given a DeepLinkRoute constructed with requiresAuth: false
    Then route.requiresAuth is false

  Feature: `build` contract

  Scenario: build returning an empty array
    Given a build closure that returns []
    When build is invoked with any params
    Then the result is empty

  Scenario: build returning one route
    Given a build closure that returns [RouteA()]
    When build is invoked
    Then the result has exactly one element which is RouteA

  Scenario: build returning many routes preserves declaration order
    Given a build closure returning [NumberedRoute(1), NumberedRoute(2), NumberedRoute(3)]
    When build is invoked
    Then the result's values are exactly [1, 2, 3] in that order — never reordered

  Scenario: build receives the exact params it was given
    Given a build closure that reads params["id"] and echoes it into a route
    When build is invoked with DeepLinkParams(["id": "42"])
    Then the produced route carries the value 42, unchanged

  Scenario: build closure capturing mutable state, invoked twice
    Given a build closure that increments a captured counter and returns it
    When build is invoked twice
    Then the first call yields 1 and the second yields 2 — not single-shot, not memoized

  Feature: RouteProvider.deepLinks default

  Scenario: A provider that declares nothing
    Given a RouteProvider that does not override deepLinks
    When deepLinks is read
    Then it returns []

  Scenario: A provider that declares two routes
    Given a RouteProvider overriding deepLinks with two DeepLinkRoute values
    When deepLinks is read
    Then it returns both, in the same order they were declared

  Feature: Conformance partitions

  Scenario: Type that does not override deepLinks still conforms
    Given MockRouteProvider<RouteA> (no deepLinks override)
    Then it satisfies RouteProvider and deepLinks resolves via the default extension

  Scenario: Type that overrides deepLinks also conforms
    Given a provider with a custom `var deepLinks: [DeepLinkRoute]`
    Then it satisfies RouteProvider and deepLinks resolves via the override
```

Self-review against the brief: both must-pin properties (array/order-preserving `build`, default `[]`) are each covered by a dedicated, exact-value assertion (not "non-empty"). All 5 existing conformances checked for zero required source changes. `protocol AppRoute` diff confirmed empty.

