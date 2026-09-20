---
id: "task_9_pulse_ui_and_settings"
status: "done"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T03:32:30+07:00"
modified: "2026-09-20T01:17:22Z"
completedAt: "2026-09-20T01:17:22Z"
labels: ["ui", "pulseui", "settings", "developer-tools", "release-isolation"]
order: "a9"
---

# Task 9: PulseUI Console, Shake Gesture & Settings Diagnostics

Epic Reference: [pulse_logger](pulse_logger.en.md) · BDD: [bdd_scenarios.md](bdd_scenarios.md) UC-5, UC-4

## Requirement Analysis

Surface the telemetry captured in Task 8: a `PulseUI` console reachable by device shake or from a
Diagnostics section in `Features/Settings`, with runtime switches for module mutes and appender
kill-switches. Everything in this task is `#if DEBUG` and must leave no trace in a Release build.

The source spec asserted release isolation in BDD 6.2 ("inspect binary symbols … no PulseUI
references") but gave it no owner. It is owned here, and it is a Definition-of-Done item rather than
a claim.

## Relevant Files & Context Pointers

- `App/Sources/UI/ShakeGestureModifier.swift` — create (`#if DEBUG`)
- `App/Sources/RootView.swift` — modify: attach the modifier and the console sheet (`#if DEBUG`)
- `Features/Settings/Sources/Settings/Presentation/Diagnostics/LoggingDiagnosticsView.swift` — create
- `Features/Settings/Sources/Settings/Presentation/Diagnostics/LoggingDiagnosticsViewModel.swift` — create
- `Features/Settings/Sources/Settings/Presentation/SettingsView.swift` — modify: add the section
- `Features/Settings/Package.swift` — modify: add the `D3NexusLogging` dependency
- `Features/Settings/Tests/SettingsTests/LoggingDiagnosticsViewModelTests.swift` — create
- `scripts/check_release_isolation.sh` — create
- Read for conventions: `Features/Settings/Sources/Settings/Presentation/Components/SettingsSectionCard.swift`,
  `SettingsViewModel.swift` (the `MviViewModel` pattern), `SettingsRouteProvider.swift`

## Design Rationale

- **The view model is the tested unit, not the view.** Toggle state, persistence and the module list
  live in `LoggingDiagnosticsViewModel`; `LoggingDiagnosticsView` stays a thin projection. This is
  what makes the ≥80% UI-tier coverage threshold reachable without snapshot fragility.
- **Shake detection via `UIDevice.deviceDidShakeNotification`** through a `ViewModifier`. The
  observer must be torn down with the view — UC-5.2's "repeated shakes do not stack sheets" is the
  behavioural symptom of getting that wrong, and `trackForMemoryLeaks` covers the structural side.
  Add an `UnremovedObserverFixture` to Task 1's `LeakFixtures` for this shape and test it as a
  discriminating pair against the real modifier: an observer that is never removed must be asserted
  to leak, the real one asserted not to.
- **`Features/Settings` gains a `D3NexusLogging` dependency.** This is a Feature → Layer 3 edge,
  which the architecture permits; it is *not* a cross-feature import, so K1 is unaffected. Confirm
  with `check_module_boundaries.sh` regardless.
- **Release isolation is scripted, not asserted.** `scripts/check_release_isolation.sh` builds the
  Release configuration and greps the binary and linked frameworks for Pulse symbols. A doc sentence
  claiming isolation is not evidence; a failing exit code is.
- **Localization — open decision.** `LOCALIZATION_RULES.md` forbids hardcoded literals, but putting
  `settings.diagnostics.*` keys in the shipped `Localizable.xcstrings` would leak developer-only
  strings into `App/Resources/backend_translations/` via `merge_localizations.py`. **Recommendation:
  English literals in this `#if DEBUG` UI, with the exemption documented inline and in
  `docs/LOCALIZATION.md`.** Confirm with the engineering lead before implementing; do not decide it
  silently in code.

Applicable skills: `ios-ui-audit`, `architecture-audit`, `code-health-audit`.

## Impact Analysis & Blast Radius

- **Target symbols**: `ShakeGestureModifier`, `LoggingDiagnosticsView`,
  `LoggingDiagnosticsViewModel`, `SettingsView`, `RootView`.
- **Downstream callers**: the host presentation hierarchy and the Settings feature graph.
- **Cross-platform bridges**: none.
- **Coverage threshold**: `LoggingDiagnosticsViewModel` ≥ 80% line.
- **Governance**: `Features/Settings` gaining a Layer 3 dependency must keep K1 and
  `check_module_boundaries.sh` green.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

Authoritative copies in [bdd_scenarios.md](bdd_scenarios.md). This task implements:

- **UC-5.1** — a shake notification in DEBUG flips presentation state and the console lists captured
  records.
- **UC-5.2** — three further shakes while the console is open leave exactly one presentation.
- **UC-5.3** — a Release build contains no PulseUI symbol and registers no shake observer.
- **UC-4.1 / 4.2** — flipping a module or appender switch changes dispatch behaviour and survives a
  process restart, driven through the view model rather than the store directly.

Plus, specific to this task:

```gherkin
[Tier A - Unit]
Scenario: The diagnostics view model deallocates with its notification observer
  Given a LoggingDiagnosticsViewModel tracked for memory leaks
  When the owning view is dismissed and teardown runs
  Then the view model is nil
  And no shake observer remains registered
```

```gherkin
[Tier B - Governance]
Scenario: Settings gains an infrastructure dependency without a cross-feature edge
  Given Features/Settings now depends on D3NexusLogging
  When bash scripts/check_module_boundaries.sh runs
  And swift test --package-path ArchTests runs
  Then both pass
  And no Features/Settings source imports Scanner
```

## Test & Verification Checklist

- [x] **Decide** — confirm the localization approach (literals vs. catalog keys) with the
      engineering lead before writing the view.
- [x] **RED** — `LoggingDiagnosticsViewModelTests` covering toggle behaviour, persistence,
      idempotent presentation, and `trackForMemoryLeaks`.
- [x] **GREEN** — implement the modifier, view model and view; wire the Settings section.
- [x] **REFACTOR** — run the `ios-ui-audit` skill (body re-evaluation, state hoisting, `Task`
      cancellation); `swiftformat`; `swiftlint --strict`.
- [x] **Tier B** — `bash scripts/check_module_boundaries.sh`;
      `swift test --package-path ArchTests`.
- [x] **Release gate** — `bash scripts/check_release_isolation.sh` exits 0 against a Release build.
- [x] **Tier C** — `tuist generate --no-open` then `xcodebuild test` on the simulator.

## Definition of Done (DoD)

- Console reachable by shake and from Settings, in DEBUG only.
- Module and appender switches change live dispatch and persist across restart.
- `check_release_isolation.sh` exists, is wired into CI, and passes.
- Release configuration builds with all of this task's code compiled out.
- `LoggingDiagnosticsViewModel` ≥ 80% line coverage; `trackForMemoryLeaks` green.
- The localization decision is recorded in the commit body and, if literals are chosen, documented as
  an exemption in `docs/LOCALIZATION.md`.
- If catalog keys are chosen instead: keys are strictly `camelCase`, namespaced under
  `settings.diagnostics.*`, free of leaf/branch collisions, and
  `python3 scripts/merge_localizations.py` reports all catalogs passing validation.
- `ArchTests`, `check_module_boundaries.sh`, SwiftLint and SwiftFormat all clean.

## Dependencies & Blockers

- Blocked by: [Task 8](task_8_pulse_appender_and_session_capture.md).
- Blocks: [Task 10](task_10_leak_sentinel_and_demo.md).

## References & Rollback

- PulseUI — <https://github.com/kean/Pulse>
- `.agents/rules/LOCALIZATION_RULES.md`; `docs/LOCALIZATION.md`
- Rollback: remove the Settings section and the `RootView` modifier. Telemetry keeps being captured;
  only the in-app viewer disappears.
