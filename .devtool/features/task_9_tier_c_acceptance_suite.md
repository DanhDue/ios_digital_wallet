---
id: "task_9_tier_c_acceptance_suite"
status: "todo"
priority: "high"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T03:42:16+07:00"
completedAt: null
labels: ["testing", "tier-c", "app", "deeplink"]
order: "a9"
---

# Task 9: Tier C End-to-End Acceptance Suite

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

Tier C in this repo means wiring and composition exercised end to end on a
simulator through the **real** `AppComposition` — not fakes. This suite is the
acceptance evidence for the epic.

**Scenarios (Source Spec §10 Tier C):**

1. `app://settings` ⇒ tab 2 selected, `tabPaths[2]` depth **0** — the tab root is
   not duplicated (the `isTabRoot` rule).
2. `app://scanner/result/ABC123` ⇒ tab 1 selected, depth **1** (root dropped),
   the result screen rendered with `ABC123`.
3. With a guard injected by the test that denies without a session and redirects
   to `[SettingsRoot]`: `app://scanner/result/ABC123` ⇒ `.pendingGuard`, tab 2
   shown, pending link stored.
4. …then publish `UserLoggedIn` ⇒ `drainPending()` runs ⇒ tab 1, result screen
   for `ABC123`, pending store empty.
5. `app://nope` ⇒ `.unmatched`, and `selectedTab` plus every `tabPaths` count are
   byte-for-byte unchanged.
6. Regression for **D3**: `router.navigate(to: ScannerResultRoute(code:))`
   renders the result screen rather than blank — the case that is impossible
   before [Task 1](task_1_any_app_route_erasure.md).

Scenarios 3 and 4 construct an `AppComposition` with a test-supplied guard, since
no shipped feature gates anything (see
[Task 7](task_7_feature_deeplink_declarations.md)). `AppComposition` already
accepts injected collaborators (`eventBus`, `cacheStore`, `secureCacheStore`), so
this follows the existing pattern rather than inventing a new seam.

## Relevant Files & Context Pointers

- `App/Tests/AppTests/DeepLinkFlowTests.swift` — **new**
- `App/Tests/AppTests/TestSupport.swift` — existing helpers; add the test guard
- `App/Sources/Composition/AppComposition.swift` — already exposes `deepLinkGuard:`
  and `tabResolver:` init parameters defaulting to production (Task 8 delivered
  them); inject the test guard through those, do not add a new seam
- `App/Sources/Composition/DeepLinkComposition.swift` — from [Task 8](task_8_host_deeplink_wiring.md)
- `App/Tests/AppTests/NavigationFlowTests.swift` — the existing Tier C precedent to mirror
- `.github/workflows/ci.yml` — the job that must actually run these

## Design Rationale

- **Assert router state, not pixels.** `selectedTab` and `tabPaths` counts are
  deterministic and fast; rendering assertions are covered at Tier A in the
  feature packages. This keeps the suite stable on CI.
- **Scenario 5 asserts *absence* of change.** The error-handling principle is
  that a junk link never disturbs the user's current screen; the only way to pin
  that is a before/after snapshot of the full router state.
- **Injecting the guard rather than faking the session** keeps the test honest
  about what it exercises: the router's redirect/pending/replay machinery, not
  Keychain behaviour.
- **This suite is worthless while CI can fall back to `xcodebuild build`** — see
  [Task 13](task_13_ci_test_fallback_removal.md), which is why that task is in
  this epic rather than deferred.
- Applicable skills in `.agents/skills/`: **`test-driven-development`**,
  **`verification-before-completion`** (paste real output, do not assert success).

## TDD Checklist

**TDD Adaptation:** this task *is* the test deliverable, so RED/GREEN/REFACTOR
applies with an inverted emphasis — the production code already exists from
Tasks 1–8. The substitution: each scenario is written and observed to fail
against a deliberately broken variant (e.g. temporarily returning
`isTabRoot: false`) before being accepted, so the suite is proven to have
teeth rather than being tautologically green.

- [ ] **RED**: write all six scenarios; for scenarios 1 and 2, verify each fails
      when `isTabRoot` handling is temporarily disabled.
- [ ] **GREEN**: restore the implementation; all six pass on a simulator.
- [ ] **REFACTOR**: extract a `makeComposition(guard:)` helper into
      `TestSupport.swift`; confirm no scenario depends on another's state.

## Definition of Done

- [ ] `tuist generate --no-open && xcodebuild test -scheme iOSDigitalWallet` —
      all six scenarios pass; output pasted into the PR.
- [ ] Each scenario has been observed failing at least once against a broken
      implementation (noted per scenario in the PR).
- [ ] No scenario shares mutable state with another; the suite passes when run in
      any order.
- [ ] `swift test --package-path ArchTests` still passes.
- [ ] SwiftLint `--strict` and SwiftFormat `--lint` clean (`App/Tests` is in the
      lint scope).

## Carried requirement from Task 8's review — close the `.onOpenURL` gap

Task 8 wired `.onOpenURL { composition.deepLinkRouter.open($0) }` but **nothing
proves SwiftUI actually calls it**. Every deep-link test to date drives
`deepLinkRouter.open(url)` directly, which is the same *callee*; deleting the
modifier leaves the whole suite green. That delivery hop is the one link with
zero coverage, and closing it is this task's job.

**The blocker Task 8 hit is a sandbox limitation, not a platform one.** On
iOS 26.x `xcrun simctl openurl` raises an OS confirmation gate ("Open in
'…'?"). Task 8 could not dismiss it because `osascript` lacks an
Accessibility grant and `idb`/`cliclick` are absent. **XCUITest can**, because it
drives SpringBoard through the automation session rather than the TCC-gated path:

```swift
let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
springboard.buttons["Open"].tap()
```

So add a UI test that opens a real URL through the OS and asserts the app
navigated. This repo has no UI test target yet — adding one is in scope for this
task. If it proves genuinely unworkable, say so explicitly with the evidence and
fall back to the ArchTests source pin (carried to Task 10), but do not silently
drop the requirement.

## Dependencies & Blockers

- Blocked by [Task 8](task_8_host_deeplink_wiring.md) — needs the real host
  wiring.
- Blocked by [Task 6](task_6_scanner_result_subfeature.md) — scenarios 2, 4 and 6
  target `ScannerResultRoute`.
- Related: [Task 13](task_13_ci_test_fallback_removal.md) must land for this
  suite to have any enforcement value in CI.

## References & Rollback

- Source Spec §10 (Tier C), §13 (acceptance criteria).
- `docs/architecture/ARCHITECTURE.md` §VI — the three-tier testing standard.
- **Rollback**: test-only. Deleting the file removes acceptance coverage but
  changes no product behaviour.
