# BDD Scenarios — Task 1: AnyAppRoute Erasure & Shell Destination Collapse

Captured from the implementer's QA pass at implementation time (2026-09-10).
Historical record of what was analysed — including partitions deliberately
excluded. The executable form is the XCTest suite; see the task's Relevant
Files. Task: [task_1_any_app_route_erasure](../../../features/task_1_any_app_route_erasure.md)

## PHASE 1 — BDD SCENARIOS

```gherkin
Feature: AnyAppRoute erasure at the NavigationPath boundary

  # --- AnyAppRoute: equality & hashing (unit level) ---

  Scenario: Same concrete type, same stored value, are equal
    Given a route value RouteA() with no stored properties
    When it is boxed twice into AnyAppRoute
    Then the two boxes are equal
    And their hashValues are equal

  Scenario: Same concrete type, same non-trivial stored value, are equal
    Given NumberedRoute(value: 7)
    When it is boxed twice into AnyAppRoute
    Then the two boxes are equal and hash equal

  Scenario: Same concrete type, different stored value, are not equal
    Given NumberedRoute(value: 1) and NumberedRoute(value: 2)
    When both are boxed into AnyAppRoute
    Then the two boxes are not equal

  Scenario: Two distinct route types with identical stored values are not equal (critical invariant)
    Given two distinct AppRoute-conforming types, each holding the same
      stored Int value (42)
    When both are boxed into AnyAppRoute
    Then the two boxes are not equal

  Scenario: Two distinct zero-property route types are not equal (empty-value edge case)
    Given RouteA() and RouteB(), both with no stored properties
    When both are boxed into AnyAppRoute
    Then the two boxes are not equal

  Scenario: wrapped round-trips the original value
    Given NumberedRoute(value: 9)
    When boxed into AnyAppRoute and `.wrapped` is read back and cast to
      NumberedRoute
    Then the recovered value equals NumberedRoute(value: 9) exactly

  Scenario: wrapped preserves dynamic type for a zero-property route
    Given RouteA()
    When boxed and `.wrapped` is cast with `is RouteA`
    Then the cast succeeds and `is RouteB` fails

  Scenario: wrapped round-trips a shared AppRoutes value
    Given AppRoutes.SettingsRoot()
    When boxed and `.wrapped` cast back
    Then it is `is AppRoutes.SettingsRoot` and equals AppRoutes.SettingsRoot()

  # --- AppRouter.navigate(to:inTab:): boxing behaviour ---

  Scenario: navigate boxes the route into AnyAppRoute before appending (happy path)
    Given an AppRouter with 1 tab
    When navigate(to: RouteA(), inTab: 0) is called
    Then tabPaths[0] equals a NavigationPath built by appending
      AnyAppRoute(RouteA()) directly

  Scenario: navigate does NOT store the bare unboxed route (erasure proof)
    Given an AppRouter with 1 tab
    When navigate(to: RouteA(), inTab: 0) is called
    Then tabPaths[0] is NOT equal to a NavigationPath built by appending the
      raw RouteA() value — proves the stored element's concrete type changed
      from RouteA to AnyAppRoute

  Scenario: two distinct empty-value route types pushed in sequence remain
            distinguishable and order-preserving after boxing
    Given RouteA() then RouteB() navigated into the same tab
    Then tabPaths[0] equals [AnyAppRoute(RouteA()), AnyAppRoute(RouteB())]
      built in that order, and does NOT equal the reverse order

  Scenario: navigate with explicit / implicit tab targeting (unchanged, regression)
  Scenario: navigate with an out-of-range tab index is a no-op (boundary, unchanged)
  Scenario: pop removes exactly one (boxed) level; no-op on empty stack (unchanged)
  Scenario: popToRoot empties only the targeted tab (unchanged)
  Scenario: pop / popToRoot / switchTab with out-of-range args are no-ops (unchanged)
  Scenario: ten rapid sequential navigate calls leave depth exactly 10 and
            unwind cleanly one pop at a time (async/ordering, unchanged
            behaviour, now over boxed elements)

  Scenario: SwiftUI back-button write-back — wholesale NavigationPath
            reassignment through the router's public tabPaths setter
    Given a tab with two boxed routes navigated in
    When the whole NavigationPath is reassigned to a shorter, independently
      built boxed path (simulating what pathBinding(for:)'s Binding setter
      does when SwiftUI pops via the back button)
    Then tabPaths[index] reflects exactly that reassigned path
    And a subsequent navigate() call appends correctly on top of it

  Scenario: AppRouter.destination(for:) is unaffected by boxing (regression,
            call site untouched, takes any AppRoute)

  # --- ShellView: single erased destination (integration) ---

  Scenario: ShellView resolves a shared AppRoutes.SettingsRoot route through
            the single AnyAppRoute destination (happy path, regression)

  Scenario: Failure mode closed — a feature-private route with NO AppRoutes
            entry resolves to real content instead of a blank screen
    Given a private test-double route declared only inside the test target
      (never a Feature import — ArchTests K6)
    And a fake RouteProvider that canHandle(_:) that type
    When the router navigates to it and the shell is hosted
    Then the fake provider's destination(for:) is invoked

  Scenario: ShellView contains exactly one .navigationDestination per tab
            stack and names zero concrete route types (structural)

  Scenario: NavigationFlowTests (Tier C) — per-tab stack counts and provider
            resolution survive the boxing change unchanged (regression)
```

Self-review against Source Spec §4.7 and the DoD: every DoD bullet maps to at
least one scenario above (equality/hash, distinct-type non-collapse, wrapped
round-trip, boxing-before-append, pop/popToRoot/guards unchanged, rapid/order,
back-button wholesale write-back, unregistered-route-renders proof, and the
structural "one destination / zero named types" check).

---

