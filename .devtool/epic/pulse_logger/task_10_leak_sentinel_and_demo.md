---
id: "task_10_leak_sentinel_and_demo"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T04:47:44+07:00"
modified: "2026-09-19T04:47:44+07:00"
completedAt: null
labels: ["memory-safety", "diagnostics", "sample", "developer-tools"]
order: "a10"
---

# Task 10: Runtime Leak Sentinel & Leak Demo Sample

Epic: [pulse_logger](pulse_logger.en.md) · BDD: [bdd_scenarios.md](bdd_scenarios.md) UC-10

## Requirement Analysis

Every leak defence in Tasks 1–9 lives **outside the running app**: `trackForMemoryLeaks` fires at
XCTest teardown, `leaks` / MallocStackLogging run in CI, and D7 removes one leak class by design.
None of them produces a log line while the app is running. A retain cycle on a real user path that
no test exercises is, today, completely silent — the gap identified when MetricKit was evaluated and
deferred (§4 Non-Goals).

This task closes that gap with two deliverables:

1. **`LeakSentinel`** — an opt-in, DEBUG-only runtime deallocation checker in
   `Packages/D3NexusLogging`. You register an object with an expected end-of-life; after a grace
   period the sentinel checks a weak reference and, if the object is still alive, emits a
   `LogRecord` at `.error` through `LogManager`.
2. **`LeakDemoFeature`** — a sample inside `Features/Settings` diagnostics, shaped like a real MVI
   feature, offering **two** flows: one that leaks and one that does not. It is the end-to-end
   acceptance path for the whole epic: tap → leak → sentinel detects → record redacted → dispatched →
   visible in the PulseUI console.

**Honesty about what this is.** `LeakSentinel` is a heuristic, not a proof. It reports "this object
outlived the scope you said it should", which is what a retain cycle looks like from the outside but
is also what a legitimately cached or re-presented object looks like. It complements `leaks` and
`trackForMemoryLeaks`; it does not replace either, and its findings are a lead to investigate rather
than a verdict.

## Relevant Files & Context Pointers

- `Packages/D3NexusLogging/Sources/D3NexusLogging/Diagnostics/LeakSentinel.swift` — create (`#if DEBUG`)
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Diagnostics/LeakSentinelClock.swift` — create: injectable clock
- `Packages/D3NexusLogging/Tests/D3NexusLoggingTests/LeakSentinelTests.swift` — create
- `Features/Settings/Sources/Settings/Presentation/Diagnostics/LeakDemo/LeakDemoAction.swift` — create
- `.../LeakDemo/LeakDemoState.swift`, `.../LeakDemo/LeakDemoEvent.swift` — create
- `.../LeakDemo/LeakDemoViewModel.swift` — create (`: MviViewModel`, K5 requires it)
- `.../LeakDemo/LeakDemoView.swift` — create (`: View`)
- `.../Diagnostics/LoggingDiagnosticsView.swift` — modify: add the entry point
- `Features/Settings/Tests/SettingsTests/LeakDemoViewModelTests.swift` — create
- Read first: `Packages/Framework/Sources/Framework/Base/MviViewModel.swift`,
  `Features/Settings/Sources/Settings/Presentation/SettingsViewModel.swift` (the MVI shape to mirror),
  `ArchTests/Tests/ArchTests/DeclRulesTests.swift` (K5 — `*ViewModel` must conform to `MviViewModel`)

## Design Rationale

- **Opt-in registration, not swizzling.** `LeakSentinel.track(_ object: AnyObject, name: String,
  gracePeriod: TimeInterval)` holds a `weak` reference and nothing else. This is the same idea
  MLeaksFinder implements, minus the UIKit `UIViewController` swizzling that made it a Non-Goal:
  opt-in works with pure SwiftUI, where there is no view-controller hierarchy to walk.
- **A grace period is mandatory, and cancellable.** SwiftUI calls `onDisappear` in situations where
  the view legitimately comes back. Registration returns a token; `onAppear` cancels it. Without
  both, the sentinel reports false positives on every navigation push.
- **Injectable clock.** The grace period must not make the test suite sleep. `LeakSentinelClock` is a
  protocol with a real implementation and a manually-advanced test double, so `LeakSentinelTests`
  runs instantly and deterministically.
- **The demo ships two flows, not one.** A "leak" button alone proves nothing — if the sentinel fired
  on everything it would look identical. The control flow does the same work with correct memory
  semantics and must produce **no** sentinel record. This is the same discriminating-pair logic the
  leak fixtures use in Task 1.
- **The leak must be realistic.** The leaking flow stores a Combine `sink` whose closure captures
  `self` strongly into a `Set<AnyCancellable>` owned by that same object — the single most common
  real leak in an `ObservableObject` + Combine codebase, and exactly the shape `MviViewModel`
  subclasses are exposed to. Not a contrived `var selfRef: Self?`.
- **Placement inside `Features/Settings`, not a new feature package.** A third feature package would
  need Tuist wiring in two template modes, a `RouteProvider`, and — if it reached `AppRoutes` — a
  `DeepLinkRoute` to satisfy K10.2. The diagnostics folder created in Task 9 is already `#if DEBUG`
  and already the developer-tools surface. K5 still applies to these files, which is desirable: it
  forces the sample into genuine MVI shape rather than a toy.
- **Extraction (E1–E4) still holds.** `LeakSentinel` takes the object, a name and a grace period —
  no host-app assumptions, no `Core` dependency. It belongs in the distributable SDK.

Applicable skills: `ios-ui-audit`, `architecture-audit`, `code-health-audit`,
`test-driven-development`.

## Impact Analysis & Blast Radius

- **Target symbols**: `LeakSentinel`, `LeakSentinelClock`, `LeakDemoAction` / `LeakDemoState` /
  `LeakDemoEvent` / `LeakDemoViewModel` / `LeakDemoView`, `LoggingDiagnosticsView`.
- **Downstream callers**: the Settings diagnostics surface only. No production code path registers
  with the sentinel in this epic — adoption on real screens is deliberately left to follow-up work,
  so this task cannot destabilise shipping flows.
- **Cross-platform bridges**: none.
- **Coverage threshold**: `Diagnostics/**` in the package ≥ 90% line (clock-driven, so fully
  testable); `LeakDemoViewModel` ≥ 80%.
- **Release isolation**: everything in this task is `#if DEBUG`; Task 11's
  `check_release_isolation.sh` must show no `LeakSentinel` or `LeakDemo` symbol in a Release binary.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

Authoritative copies in [bdd_scenarios.md](bdd_scenarios.md), UC-10. This task implements:

```gherkin
[Tier A - Unit]
Scenario: The sentinel reports an object that outlives its declared scope
  Given a LeakSentinel with a manually advanced clock and a spy LogManager
  And an object registered with a grace period of 3 seconds, held by a deliberate strong reference
  When the scope is ended and the clock advances past 3 seconds
  Then exactly one LogRecord at level .error is dispatched
  And its message names the registered object
  And its metadata carries the registered name and the elapsed grace period
```

```gherkin
[Tier A - Unit]
Scenario: An object that deallocates within its grace period produces no record
  Given a LeakSentinel with a manually advanced clock and a spy LogManager
  And an object registered with a grace period of 3 seconds and then released
  When the clock advances past 3 seconds
  Then zero LogRecords are dispatched
```

```gherkin
[Tier A - Unit]
Scenario: A cancelled registration never reports, even if the object is still alive
  Given an object registered with the sentinel
  When the returned token is cancelled before the grace period elapses
  And the clock advances well past the grace period
  Then zero LogRecords are dispatched
  # Guards the SwiftUI onDisappear-then-onAppear false positive.
```

```gherkin
[Tier A - Unit]
Scenario: The sentinel holds no strong reference to what it tracks
  Given an object registered with the sentinel and tracked for memory leaks
  When the caller releases its own reference
  Then the object deallocates immediately
  And the sentinel itself deallocates cleanly at teardown
```

```gherkin
[Tier A - Unit]
Scenario: The leaking demo flow really leaks
  Given a LeakDemoViewModel driven through the leaking action
  When the view model goes out of scope
  Then a weak reference to it is still non-nil
  # If this ever passes as nil, the demo has stopped demonstrating anything.
```

```gherkin
[Tier A - Unit]
Scenario: The control demo flow does not leak
  Given a LeakDemoViewModel driven through the non-leaking action
  When the view model goes out of scope
  Then a weak reference to it is nil
```

```gherkin
[Tier C - Integration]
Scenario: The leak is visible in the in-app console end to end
  Given a DEBUG build with the diagnostics section reachable from Settings
  When the developer opens Leak Demo, taps the leaking action, and navigates back
  And the grace period elapses
  And the developer opens the console by shaking the device
  Then a .error record from the leak sentinel module is listed
  And it names LeakDemoViewModel
  And the same flow performed with the control action produces no such record
```

```gherkin
[Tier B - Governance]
Scenario: The sample obeys the architecture rules like a real feature
  Given the LeakDemo sources under Features/Settings/Sources/Settings/Presentation
  When swift test --package-path ArchTests runs
  Then K5 confirms LeakDemoViewModel conforms to MviViewModel and LeakDemoView conforms to View
  And K2 confirms the Presentation layer references no Data-layer type
  And K1 and check_module_boundaries.sh stay green
```

```gherkin
[Tier B - Governance]
Scenario: None of it reaches Release
  Given a Release configuration build
  When check_release_isolation.sh inspects the binary
  Then no LeakSentinel or LeakDemo symbol is present
```

## Test & Verification Checklist

- [ ] **RED** — `LeakSentinelTests` against the injectable clock (report, no-report, cancellation,
      no-strong-reference), and `LeakDemoViewModelTests` as a discriminating pair (leaking flow
      asserts `XCTAssertNotNil`, control flow asserts `XCTAssertNil`). Confirm each fails first.
- [ ] **GREEN** — implement `LeakSentinel`, `LeakSentinelClock`, and the MVI demo quartet.
- [ ] **REFACTOR** — run `ios-ui-audit`; `swiftformat`; `swiftlint --strict`. Confirm the test suite
      never sleeps on a real grace period.
- [ ] **Tier B** — `swift test --package-path ArchTests` (K5 / K2 on the new sample);
      `bash scripts/check_module_boundaries.sh`; `bash scripts/check_release_isolation.sh`.
- [ ] **Tier C — the manual demo, run and recorded** — `tuist generate --no-open`, run on a
      simulator, Settings → Diagnostics → Leak Demo → leaking action → back → wait out the grace
      period → shake → confirm the `.error` record is in the console. Repeat with the control action
      and confirm **no** record. Attach both observations to the task before closing it.

**TDD note**: the Tier C step is a human observation and cannot be automated by the harness in this
epic. It is still a required, recorded acceptance step — the Tier A discriminating pair is what
protects it from silently rotting between runs.

## Definition of Done (DoD)

- `LeakSentinel` reports on a held object, stays silent on a released one, honours cancellation, and
  holds no strong reference to what it tracks.
- The test suite exercises every grace period through the injectable clock and never sleeps.
- The demo is a genuine MVI feature — K5 and K2 pass on it unmodified.
- The leaking flow is proven to leak and the control flow proven not to, as a discriminating pair.
- The end-to-end console observation is performed and recorded, for both flows.
- `Diagnostics/**` ≥ 90% line coverage; `LeakDemoViewModel` ≥ 80%.
- `check_release_isolation.sh` shows no `LeakSentinel` / `LeakDemo` symbol in Release.
- `ArchTests`, `check_module_boundaries.sh`, SwiftLint and SwiftFormat all clean.

## Dependencies & Blockers

- Blocked by: [Task 9](task_9_pulse_ui_and_settings.md) — the console must exist before a leak can be
  observed in it.
- Blocks: [Task 11](task_11_acceptance_and_governance.md).

## References & Rollback

- HLD §4 Non-Goals — MetricKit evaluated and deferred; this task covers the gap that discussion named
- MLeaksFinder — the prior art, and why opt-in registration replaces UIKit swizzling here
- Rollback: delete `Diagnostics/` from the package and `LeakDemo/` from Settings. The logging
  pipeline is untouched; no production path registers with the sentinel.
