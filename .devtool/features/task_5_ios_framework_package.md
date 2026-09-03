---
id: "task_5_ios_framework_package"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["architecture", "spm", "mvi"]
order: "a5"
---

# Task 5: Create `Framework` SPM local package (MviViewModel)

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Create `Sources/Framework/` — the iOS equivalent of Flutter `packages/framework` and Android `:framework`. Contains the MVI base classes that every Feature's ViewModel inherits from.

**Contents**:

| Type | File | Kotlin equivalent |
|---|---|---|
| `class MvvmViewModel: ObservableObject` | `Base/MvvmViewModel.swift` | `MvvmViewModel.kt` |
| `enum ViewState<STATE>` | `Base/ViewState.swift` | `ViewState.kt` (sealed class) |
| `class MviViewModel<STATE,ACTION,EVENT>: MvvmViewModel` | `Base/MviViewModel.swift` | `MviViewModel.kt` |

Combine mapping (1:1 with Kotlin):
- `@Published var uiState: STATE` ≈ `StateFlow<STATE>`
- `@Published var viewState: ViewState<STATE>` ≈ `StateFlow<ViewState<STATE>>`
- `PassthroughSubject<EVENT, Never> eventSubject` ≈ buffered `Channel<EVENT>` (1 consumer convention)
- `PassthroughSubject<EVENT, Never> sharedEventSubject` ≈ `SharedFlow<EVENT>`
- `func dispatch(_ action: ACTION)` → `onAction(_:)` ≈ `dispatch(action)` → `onAction(action: ACTION)`
- `func reduce(_ transform: (inout STATE) -> Void)` ≈ `reduce { copy(...) }`

`Package.swift`: depends on `Core` (local), `Combine` (system). Targets: `Framework` (lib) + `FrameworkTests`.

## Relevant Files & Context Pointers

- `Sources/Framework/Package.swift` — **NEW**
- `Sources/Framework/Sources/Framework/Base/MvvmViewModel.swift` — **NEW**
- `Sources/Framework/Sources/Framework/Base/ViewState.swift` — **NEW**
- `Sources/Framework/Sources/Framework/Base/MviViewModel.swift` — **NEW**
- `Sources/Framework/Tests/FrameworkTests/MviViewModelTests.swift` — **NEW**
- `iOSDigitalWallet.xcodeproj` — add `Framework` local package reference
- Reference: `.devtool/epic/flutter_super_app_template/2026-08-29-flutter-super-app-template-design.md` §3.5 (Kotlin → Swift mapping table)
- Source spec §5 (full MviViewModel code)

## Design Rationale

`dispatch()` is `final` — prevents subclasses from bypassing the single-entry-point contract (same rationale as making Kotlin's `dispatch` non-overridable). `onAction()` is `open` — the intended override point. `reduce()` mutates `uiState` via `inout` — idiomatic Swift value-type mutation that mirrors Kotlin's `copy()` on data class.

`eventSubject` uses `PassthroughSubject` with a documented convention ("only 1 subscriber") instead of a true single-consumer channel — Combine has no buffered single-consumer channel primitive. This matches the decision in `flutter_super_app_template` §3.5.

## TDD Checklist

- [ ] **RED**: `MviViewModelTests` — `dispatch` calls `onAction`; `reduce` updates `uiState`; `startLoading` sets `viewState` to `.loading`; `handleError` sets `.error`; `showContent` sets `.content`.
- [ ] **RED**: `eventSubjectTests` — `eventSubject.send(event)` received by subscriber; `sharedEventSubject` received by two subscribers simultaneously.
- [ ] **RED**: `ViewStateTests` — enum cases wrap correctly; `ViewState<Int>.content(42)` extracts value.
- [ ] **GREEN**: Implement `MvvmViewModel`, `ViewState`, `MviViewModel` to pass all tests.
- [ ] **REFACTOR**: KDoc comments on all public API. SwiftLint + SwiftFormat clean.

## Definition of Done

- `Sources/Framework/` builds (`swift build`). Unit tests green.
- App target imports `Framework` without error.
- `dispatch()` is marked `final`; `onAction()` is `open`.
- SwiftLint + SwiftFormat clean. Coverage ≥ 80%.

## Dependencies & Blockers

- Blocked by [Task 4](task_4_ios_core_package.md) (`Framework` depends on `Core`).
- Blocks [Task 8](task_8_ios_platform_package.md) (`Platform` depends on `Framework`).
- Blocks [Task 11](task_11_ios_shell.md) (`ShellViewModel` inherits from `MviViewModel`).

## References & Rollback

- Source spec §5 (MviViewModel detail + Kotlin mapping table).
- Rollback: remove `Sources/Framework/` + remove package reference from project.
