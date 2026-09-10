# BDD Scenarios — Task 5: DeepLinkRouter Engine, Guard/Tab Seams, Pending Replay

Captured from the implementer's QA pass at implementation time (2026-09-10).
Historical record of what was analysed — including partitions deliberately
excluded. The executable form is the XCTest suite; see the task's Relevant
Files. Task: [task_5_deeplink_router_engine](../../../features/task_5_deeplink_router_engine.md)

## PHASE 1 — BDD SCENARIOS

### BDD SCENARIOS

```gherkin
Feature: DeepLinkRouter resolution
  Scenario: No providers registered
    Given a DeepLinkRouter with no registered providers
    When open(url) is called for any URL
    Then the outcome is .unmatched

  Scenario: One provider, no patterns
    Given a provider registered with an empty deepLinks array
    When open(url) is called
    Then the outcome is .unmatched

  Scenario: First-match-wins across two providers (existential-typed registration)
    Given provider1 declares "/settings" -> [RouteA] and provider2 declares "/settings" -> [RouteB]
    And both are registered through `let p: any RouteProvider = ...` bindings, in that order
    When open("app://settings") is called
    Then the outcome is .opened and RouteA (provider1's) is what was pushed, not RouteB

  Scenario: No pattern matches
    Given a provider declaring only "/settings"
    When open("app://wallet/send") is called
    Then the outcome is .unmatched and no tab's path count changed

  Scenario: build returns []
    Given a route whose build(_:) always returns []
    When open(url) is called for a URL that matches its pattern
    Then the outcome is .unmatched and the guard is never consulted (0 invocations)

  Scenario: malformed URL
    Given DeepLink.init?(url:) already exhaustively proves its nil path requires a string
      that fails at URL(string:) construction (Task 2, DeepLinkTests) — meaning no URL
      value exists at the router boundary to trigger that specific nil branch
    When open(url) is called with a syntactically valid but wholly unregistered URL
    Then the outcome is .unmatched, same as any other non-match, with no crash

Feature: DeepLinkRouter navigation algorithm
  Scenario: .allow with resolver absent
    Given no TabResolver is configured
    When a matched stack is allowed
    Then AppRouter.selectedTab is unchanged, popToRoot(inTab: currentTab) ran, and the
      stack was pushed in exactly declaration order

  Scenario: .allow with resolver, tab-root placement
    Given a TabPlacement(tab: N, isTabRoot: true) for the stack's first route
    When the stack is allowed
    Then exactly the first element is dropped and the remainder is pushed intact

  Scenario: .allow with resolver, non-root placement
    Given a TabPlacement(tab: N, isTabRoot: false)
    When the stack is allowed
    Then the router switches to tab N and pushes the FULL stack (nothing dropped)

  Scenario: stack of 1, 2, many — declaration order pinned
    Given stacks of increasing length (1, 2, 3 elements)
    When allowed
    Then the pushed NavigationPath equals the exact declared sequence (order-asserted via
      AnyAppRoute-boxed NavigationPath equality, not count/contains)

  Scenario: single-element stack that is the tab root
    Given a 1-route stack where that route IS the tab's root (isTabRoot: true)
    When allowed
    Then zero routes are pushed (dropFirst leaves []), yet outcome is still .opened and the
      tab still switched — "nothing left to push" is not a failure

  Scenario: resolver returns nil for this route
    Given a TabResolver that answers nil for the specific route
    When the stack is allowed
    Then the router falls back to the current tab, and the resolver was still consulted once

  Scenario: tab index boundaries — 0 and last valid index
    Given a 3-tab router and a resolver returning tab: 0, then separately tab: 2 (tabCount-1)
    When allowed
    Then both boundary indices are honoured exactly

  Scenario: out-of-range tab falls back, never a silent no-op
    Given a resolver returning TabPlacement(tab: 99, isTabRoot: false) on a 2-tab router
    When the stack is allowed
    Then the router falls back to selectedTab, THE STACK STILL LANDS on the fallback tab,
      the outcome is still .opened (never a false .opened-but-nothing-moved), and the bad
      placement is logged exactly once

Feature: DeepLinkRouter gating
  Scenario: guard absent
    Given no DeepLinkGuard is configured
    When a stack matches
    Then it is treated as .allow (zero-configuration deep links work)

  Scenario: .allow
    Given a guard that returns .allow
    Then the stack is pushed and outcome is .opened

  Scenario: .redirect(retainPending: true)
    Given a guard that redirects the original stack to a target stack, retaining
    When open(url) is called
    Then the pending link is stored, the redirect stack (not the original) is pushed,
      and the outcome is .pendingGuard; the guard was invoked exactly twice (original,
      then the redirect target — see re-entrancy feature below)

  Scenario: .redirect(retainPending: false)
    Given a guard that redirects without retaining
    When open(url) is called, then drainPending() is called
    Then the redirect stack is still pushed (outcome .pendingGuard) but drainPending() is a
      true no-op afterward — nothing was stored

  Scenario: .deny
    Given a guard that denies
    When open(url) is called
    Then outcome is .denied and any previously-pending link is cleared

  Scenario: requiresAuth true / false reaches the guard unchanged
    Given routes declared with requiresAuth: true and requiresAuth: false respectively
    When opened
    Then the guard's first invocation carries that exact boolean, verbatim

Feature: DeepLinkRouter pending store
  Scenario: empty store
    Given nothing is pending
    When drainPending() is called
    Then it is a no-op: 0 guard invocations, AppRouter state byte-for-byte unchanged

  Scenario: populated then drained
    Given a redirect stored a pending link, and the guard's answer later changes to .allow
    When drainPending() is called
    Then the ORIGINAL matched stack (not the redirect target) is replayed to the correct tab

  Scenario: a second open() replaces the stored link
    Given link A is pending (redirect+retain), then link B also redirects+retains
    When drainPending() is finally called
    Then link B's stack is what replays — link A was superseded, never both

  Scenario: pending cleared on success
    Given a pending link exists, then an unrelated link opens directly (.allow)
    Then the old pending link is gone (drainPending() becomes a no-op)

  Scenario: pending cleared on deny
    Given a pending link exists, then a new link's guard call denies
    Then the old pending link is cleared too (not just the new one refused)

  Scenario: pending cleared on retainPending: false after a prior pending was stored
    Given link A stored a pending entry, then link B redirects with retainPending: false
    Then the store ends up empty — B's "false" clears A's leftover, not just skips storing B

  Scenario: drain after the guard's answer changes
    Covered by "populated then drained" above (mode flips from redirect to allow between
    open() and drainPending())

Feature: Redirect re-entrancy
  Scenario: a guard that redirects its own redirect target must terminate
    Given a guard that answers .redirect for EVERY input, including the redirect target
    When open(url) is called
    Then outcome is .denied and the guard was invoked EXACTLY TWICE — original once,
      redirect target once — never a third call (bounded count, not just "no hang")

  Scenario: redirect target evaluated with requiresAuth: false regardless of the original
    Given a route declared requiresAuth: true that redirects
    When the router evaluates the redirect target
    Then that second guard call's requiresAuth is false — "a redirect target must be
      reachable without auth" (Source Spec §4.6) is pinned as an exact argument, not prose

Feature: State-mutation invariant (every failure path leaves AppRouter untouched)
  Scenario: .unmatched
    Given pre-existing router state (some tab already has a stack)
    When open(url) yields .unmatched
    Then selectedTab and every tabPaths count are identical before/after

  Scenario: .denied
    Same shape, for a guard .deny decision

  Scenario: a .redirect whose own target is not .allow (stores nothing, changes nothing)
    Given a guard that redirects the original, then denies the redirect target itself
    When open(url) is called
    Then outcome is .denied, AppRouter is byte-for-byte unchanged (the redirect stack was
      NEVER pushed — the re-entrancy guard fires before any navigation happens), and
      nothing was left pending

Feature: Async / ordering (single-threaded, MainActor-serialised)
  Scenario: two open() calls in immediate succession
    Given two different URLs matching two different routes, both landing on the same tab
    When both are opened back-to-back
    Then the second call's popToRoot cleanly replaces the first call's push — no
      interleaving corruption, final state reflects only the second call

  Scenario: open() called immediately after drainPending()
    Given a drain that succeeds (.allow) followed immediately by a new open() call
    Then both resolve correctly in sequence with no state corruption
```

### Self-review against the brief

- Three must-pin behaviours (brief, "easy to get wrong"): **isTabRoot dedup** →
  `testIsTabRootDropsExactlyTheFirstElementAndNoMore` +
  `testSingleElementStackThatIsTheTabRootPushesNothingButStillSwitchesAndSucceeds`.
  **Pending holds exactly one, no TTL** → the five Pending-section scenarios above.
  **Redirect re-entrancy terminates** → the two Redirect-re-entrancy scenarios, with a
  bounded call-count assertion, not "did not hang".
- Definition of Done's equivalence partitions (guard absent/allow/redirect/deny; resolver
  absent/tab-root/non-root; pending empty/populated/replaced): every one has a scenario
  above.
- DoD "no failure path mutates AppRouter": three dedicated State-mutation-invariant tests,
  each comparing `selectedTab` and every `tabPaths.count` before/after.
- Sequence diagram §4.3 / design doc §4.6: cross-checked the redirect handling against the
  design doc's explicit prose ("the router evaluates a redirect target once; if that
  evaluation is not `.allow`, the outcome is `.denied`") — see Concerns below for the
  ambiguity this resolved.
- Nothing in the DoD was left without a scenario.

---

