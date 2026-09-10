# BDD Scenarios — Task 8: Host Wiring (Composition, onOpenURL, URL Scheme, UserLoggedIn)

Captured from the implementer's QA pass at implementation time (2026-09-10).
Historical record of what was analysed — including partitions deliberately
excluded. The executable form is the XCTest suite; see the task's Relevant
Files. Task: [task_8_host_deeplink_wiring](../../../features/task_8_host_deeplink_wiring.md)

### BDD SCENARIOS

```markdown
Feature: SessionDeepLinkGuard — the host's authentication seam
  Scenario: requiresAuth false, no token → .allow
  Scenario: requiresAuth false, with token → .allow (token irrelevant)
  Scenario: requiresAuth true, with token → .allow
  Scenario: requiresAuth true, no token, empty redirectTo (boundary) → .deny
  Scenario: requiresAuth true, no token, configured redirectTo (boundary) → .redirect(to:, retainPending: true)
  Scenario: an empty-string access token still counts as "present" (nil vs "" boundary)

Feature: ShellTabResolver — pinned to ShellView's real 3-tab layout
  Scenario: ScannerRoot → TabPlacement(tab: 1, isTabRoot: true)
  Scenario: SettingsRoot → TabPlacement(tab: 2, isTabRoot: true)
  Scenario: a feature-private route (ScannerResultRoute) → nil
  Scenario: an unrelated/unregistered route → nil

Feature: Deep-link registration
  Scenario: one entry per declared pattern, resolvable (Scanner ×2 + Settings ×1, via full AppComposition)
  Scenario: registration order matches providers order (first match wins on a colliding pattern, both directions tested)
  Scenario: registration driven through an existential `any RouteProvider` binding still reads the overridden `deepLinks`
  Scenario: a provider declaring no deepLinks contributes nothing

Feature: UserLoggedIn → drainPending()
  Scenario: publishing UserLoggedIn drains a pending redirected link (guard flips to allow, replay observed via tab change)
  Scenario: publishing an unrelated event (AppLifecycleChanged) does not drain

Feature: AppComposition — default vs injected DeepLinkGuard
  Scenario: no injected guard → production SessionDeepLinkGuard(session:, redirectTo: []) → .denied for a gated fake route
  Scenario: injected FakeDeepLinkGuard → used instead of the default; callCount == 1

Feature: Adversarial / boundary
  Scenario: open() with a URL matching nothing → .unmatched, router state byte-for-byte unchanged
  Scenario: two URLs opened in immediate succession → both resolve independently, second wins cleanly
```

Self-review against the DoD before Phase 2: covered guard (all 4 spec cases + 2 boundary variants), resolver (all 4 partitions pinned to the real `ShellView` layout), registration (order, existential binding, one-per-pattern, empty-provider), `UserLoggedIn`/`drainPending` (positive + negative), the `AppComposition` injection seam (default vs injected), and adversarial cases. Confirmed complete — proceeded to Phase 2.

---

