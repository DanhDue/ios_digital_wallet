---
id: "task_5_ios_framework_package"
status: "done"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: "2026-09-03T11:43:11Z"
labels: ["architecture", "spm", "mvi"]
order: "a5"
---

# Task 5: Create `Framework` SPM package (MviViewModel + async-effect)

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: A (behavioral).** MVI base is where race/ordering/teardown bugs live — the scenario list below is deliberately heavy on async and emission order.

## Requirement Analysis

`Packages/Framework/` — depends on `Core` only. The MVI base every Feature/Shell ViewModel inherits from. Mirror of Flutter `packages/framework` / Android `:infra:framework`.

Contents (`Sources/Framework/Base/`):
- `MvvmViewModel.swift` — `@MainActor open class MvvmViewModel: ObservableObject { var cancellables; open func onClear(); deinit }`.
- `ViewState.swift` — `enum ViewState<STATE> { case loading, error(Error), content(STATE) }`.
- `MviViewModel.swift` — `@MainActor open class MviViewModel<STATE, ACTION, EVENT>: MvvmViewModel` per Source Spec §5.4: `@Published private(set) uiState`, `@Published private(set) viewState`, `eventSubject` / `sharedEventSubject` (`PassthroughSubject<EVENT, Never>`), `final dispatch(_:)` → `open onAction(_:)`, `reduce(_ transform: (inout STATE) -> Void)`, `startLoading/handleError/showContent`, `emit/emitShared`.
- `AsyncEffect.swift` — Source Spec §5.5: `effectTasks: [AnyHashable: Task<Void, Never>]` on `MviViewModel`; `func launch(_ key:_:)` cancels any running task for `key` before starting; `func cancelEffects()`; `onClear()` calls `cancelEffects()`.

`Package.swift`: `Framework` (depends `Core`) + `FrameworkTests`, `.iOS(.v16)`.

## Relevant Files & Context Pointers

- `Packages/Framework/Package.swift`, `Packages/Framework/Sources/Framework/Base/*.swift`, `Packages/Framework/Tests/FrameworkTests/**` — **NEW**
- `Tuist/Package.swift` — add `.package(path: "Packages/Framework")` in marker region
- Source Spec §5 (full code), §5.5 (async-effect), Changelog #13
- Flutter spec §3.5 (Kotlin→Swift mapping table)

## Design Rationale

`dispatch()` is `final` — the single-entry-point contract can't be bypassed (matches Kotlin's non-overridable `dispatch`). `onAction()` is `open`. `reduce` mutates `uiState` via `inout` (value-type idiom mirroring `copy()`). The §5.5 `launch(key:)` helper is the Swift analogue of `viewModelScope.launch` + `switchMap`: a new action with the same key cancels the in-flight effect, so "rapid triple dispatch → only the last effect reaches `reduce`" is a structural guarantee, not luck.

**Applicable skills:** none specific.

### BDD Scenarios

```gherkin
# Happy path
Scenario: dispatch routes to onAction
  Given a subclass recording actions
  When dispatch(.load)
  Then onAction(.load) was called exactly once

Scenario: reduce mutates uiState
  When reduce { $0.count += 1 } from count 0
  Then uiState.count is 1

# State transitions + emission order
Scenario: viewState sequence for a successful load is [.loading, .content]
  Given a ViewState recorder subscribed before dispatch
  When onAction runs startLoading() then showContent()
  Then the recorded sequence is exactly [.loading, .content(state)]

Scenario: viewState sequence for a failed load is [.loading, .error]
Scenario: uiState @Published emits the initial value then each reduce result, in order

# Async / race
Scenario: three rapid dispatches of the same effect key -> only the last effect's reduce is observed
  Given launch("load") runs an awaitable that reduces state to its input
  When dispatch(.load(1)), dispatch(.load(2)), dispatch(.load(3)) with no await between
  Then uiState ends at 3 and the effects for 1 and 2 were cancelled (CancellationError observed)

Scenario: launch with distinct keys run concurrently (no mutual cancellation)
Scenario: an effect that checks Task.isCancelled stops promptly after a superseding dispatch

# Failure injection
Scenario: an effect throwing (non-cancellation) calls handleError and sets viewState .error
Scenario: onClear() during an in-flight effect cancels it; no reduce happens afterward

# Events
Scenario: eventSubject delivers to its single subscriber
Scenario: sharedEventSubject delivers the same event to two subscribers
Scenario: publishing an event with no subscriber does not crash

# Resource teardown
Scenario: after onClear(), cancellables is empty and effectTasks is empty
Scenario: deinit does not retain the ViewModel (weak ref is nil after scope exit)
Scenario: no @Published emission is delivered after onClear()
```

### TDD Tests

- `MviViewModelTests` — dispatch→onAction count; reduce; `startLoading/handleError/showContent` set `viewState`.
- `EmissionOrderTests` — a `Recorder` sinks `viewState` / `uiState` into `[Value]`; assert the exact array for success and failure flows.
- `AsyncEffectTests` — `launch(key:)` with an `AsyncStream`-gated operation; fire 3 dispatches; assert final state + that superseded tasks saw `CancellationError`; distinct keys run in parallel (both complete).
- `EffectFailureTests` — throwing effect → `viewState == .error`; cancellation is swallowed (not surfaced as `.error`).
- `TeardownTests` — `onClear()` empties `cancellables` + `effectTasks`; `weak var vm` is nil after the strong ref drops; a sink attached pre-`onClear` receives nothing after.
- `EventSubjectTests` — single vs shared delivery; no-subscriber send.
- All `@MainActor`; async waits via `XCTestExpectation` / `await fulfillment`.

### RED → GREEN

- RED: tests compile against signatures with `fatalError()` bodies and fail. The race test is designed to fail loudly if `launch` does not cancel the previous task (final state would be nondeterministic / not 3).
- GREEN: implement `MviViewModel` + `AsyncEffect` minimally; the race test passing is the proof the cancel-on-new-action wiring is correct.

## Definition of Done

- `swift test --package-path Packages/Framework` green; every scenario has a passing test.
- `dispatch()` is `final`, `onAction()` is `open`; `onClear()` cancels effects.
- Emission-order tests assert sequences, not just terminal values.
- Coverage ≥ 80%. SwiftLint/SwiftFormat clean. Depends only on `Core`.

## Dependencies & Blockers

- Blocked by [Task 4](task_4_ios_core_package.md).
- Blocks [Task 8](task_8_ios_platform_package.md) is **not** required (Platform → Core only), but blocks [Task 10](task_10_ios_shell.md), [Task 11](task_11_ios_settings_feature.md), [Task 12](task_12_ios_scanner_and_composition.md).

## References & Rollback

- Source Spec §5, §5.5. Flutter spec §3.5.
- Rollback: remove `Packages/Framework/` + its marker line. `Core` unaffected.
