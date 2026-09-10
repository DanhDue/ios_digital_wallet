# BDD Scenarios — Task 9: Tier C End-to-End Acceptance Suite

Captured from the implementer's QA pass at implementation time (2026-09-11).
Historical record of what was analysed — including partitions deliberately
excluded. The executable form is the XCTest/XCUITest suite; see the task's
Relevant Files. Task: [task_9_tier_c_acceptance_suite](../../../features/task_9_tier_c_acceptance_suite.md)

## PHASE 1: BDD SCENARIOS

```gherkin
Feature: Deep-link acceptance (Source Spec §10 Tier C)
  Every scenario drives a real, composed AppComposition — real AppRouter,
  real ScannerRouteProvider/SettingsRouteProvider, real ShellTabResolver.
  Only the DeepLinkGuard is ever swapped (scenarios 3/4), through the
  deepLinkGuard: seam AppComposition already exposes.

  Background:
    Given a fresh AppComposition built via makeComposition(guard:) —
      a fresh AppEventBus, a fresh in-memory SecureCacheStore, and (for
      scenarios 3/4) a fresh FakeDeepLinkGuard local to that one test
    # No test shares any mutable state — see "State isolation" below.

  Scenario 1: Settings deep link selects its tab without duplicating its root
    Given the router is on tab 0 (moved away from the cold-start default)
    When "app://settings" is opened
    Then the outcome is .opened
    And selectedTab is 2
    And tabPaths[2].count is 0 (root dropped, not duplicated)
    And tabPaths[0].count and tabPaths[1].count are both 0

  Scenario 2: Scanner-result deep link selects tab 1, drops the root, carries the code
    When "app://scanner/result/ABC123" is opened
    Then the outcome is .opened
    And selectedTab is 1
    And tabPaths[1].count is 1 (ScannerRoot dropped, only ScannerResultRoute remains)
    And tabPaths[0].count and tabPaths[2].count are both 0

  Scenario 3: A guard that denies without a session redirects and retains the link pending
    Given a guard that redirects any ScannerResultRoute stack to [SettingsRoot],
      and allows SettingsRoot itself (a redirect target must be reachable)
    When "app://scanner/result/ABC123" is opened
    Then the outcome is .pendingGuard
    And selectedTab is 2, tabPaths[2].count is 0 (redirect target shown, not duplicated)
    And tabPaths[1].count is 0 (the original stack was never pushed)
    And draining again consults the guard again (proof something was pending)

  Scenario 4: Publishing UserLoggedIn drains the pending link and completes the original navigation
    Given the guard from Scenario 3, still parked pending
    When the simulated session becomes present and UserLoggedIn is published
    Then — deterministically, no fixed sleep — selectedTab becomes 1
    And tabPaths[1].count is 1 (ScannerResultRoute replayed)
    And a second drain no longer consults the guard (pending store is now empty)

  Scenario 5: An unmatched link leaves the router byte-for-byte unchanged
    Given non-trivial prior state (SettingsRoot pushed to tab 2, tab 1 selected)
    When "app://nope" is opened
    Then the outcome is .unmatched
    And selectedTab and every tabPaths[i].count are identical to before

  Scenario 6: Regression D3 — direct navigate(to:) to a feature-private route
    When AppRouter.navigate(to: ScannerResultRoute(code:), inTab: 1) is called directly
      (bypassing the deep-link engine entirely)
    Then tabPaths[1].count is 1
    And the fully composed RootView hosts that state in a real key UIWindow
      without crashing

  Scenario 7 (extended BVA — ordering): Two links in immediate succession
    When "app://settings" then "app://scanner/result/ABC123" are opened back to back
    Then only the second link's state is observable — no residue from the first

  Scenario 8 (extended BVA — boundary): A newer pending link supersedes an older one
    Given a guard that always redirects to [SettingsRoot]
    When two different scanner-result links are opened in succession (both pending)
    And the guard is then set to allow everything, and drainPending() is called
    Then exactly one guard consultation happens on drain (single-slot store, not a queue)
    And the replayed link is the second one (FIRST01 was discarded, not queued)

  Scenario 9 (UI, carried requirement): .onOpenURL delivery hop
    Given the app is freshly launched
    When XCUIApplication.open(url) delivers "iosdigitalwallet://scanner/result/UITESTCODE123"
      through the real OS URL-opening path (not deepLinkRouter.open(url:) in process)
    Then the Result screen's "scanner.result.code" text becomes visible
    And its label equals "UITESTCODE123"

  Scenario 10 (UI, extended): the same hop, a different observable
    When "iosdigitalwallet://scanner" is opened through the OS
    Then the Scanner tab button (not the cold-start default) becomes selected
```

**Boundary Value Analysis / Equivalence Partitioning, beyond the six:**
- *Ordering*: Scenario 7 covers "two links opened in immediate succession."
  Scenario 8 covers "a link opened while a pending link is stored" — the
  brief's own phrase.
- *State isolation*: every `DeepLinkFlowTests` method calls
  `makeComposition(guard:)`, which builds a **fresh** `AppEventBus`, a
  **fresh** `InMemorySecureCacheStore`, and (where used) a **fresh**
  `FakeDeepLinkGuard` closed over test-method-local `var`s (e.g. `hasSession`
  in scenario 4). Nothing is `static`, nothing is `AppEventBus.shared`.
  Verified in practice, not just by inspection: the suite was run standalone
  (`-only-testing:iOSDigitalWalletTests/DeepLinkFlowTests`) and as part of
  the full 47-test target, both green, in both the framework's own
  (effectively randomizable per-class) ordering.
- *The absence assertion (scenario 5)*: the "before" snapshot is
  `(selectedTab, tabPaths.map(\.count))`, captured **after** deliberately
  seeding non-trivial state (a push to tab 2 and a tab switch to 1) so the
  assertion is a real diff, not a vacuous all-zeros comparison. The "after"
  snapshot is the identical projection, compared with `XCTAssertEqual`
  against the exact stored tuple/array.
- *The replay path (scenario 4)*: no `sleep`. `DeepLinkReplayObserver`
  subscribes to `UserLoggedIn` with `.receive(on: DispatchQueue.main)` at
  `AppComposition.init` time. The test subscribes its **own** sink to the
  same event, also via `.receive(on: DispatchQueue.main)`, but **after**
  composition is built — so its dispatch is enqueued on the main queue after
  the replay observer's. Publishing once and waiting on an `XCTestExpectation`
  fulfilled by the test's own sink therefore deterministically guarantees the
  replay's `drainPending()` already ran by the time the expectation fires.

**Self-review against the Definition of Done**, before Phase 2:
- [x] All six scenarios pass on a simulator via the corrected
      `xcodebuild test -workspace ... -scheme iOSDigitalWallet` invocation.
- [x] Each scenario individually observed failing against a broken
      implementation (see Phase 3 below — all six, not just 1–2).
- [x] No scenario shares mutable state with another (fresh composition per
      test; verified by running standalone and full-suite).
- [x] `swift test --package-path ArchTests` still passes (31/31).
- [x] SwiftLint `--strict` and SwiftFormat `--lint` clean, with `App/Tests`
      **and** `App/UITests` genuinely in the lint scope (a pre-existing gap
      closed — see "Concerns").

---

