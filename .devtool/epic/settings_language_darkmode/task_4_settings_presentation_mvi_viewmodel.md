---
id: "task_4_settings_presentation_mvi_viewmodel"
status: "done"
priority: "high"
assignee: null
epic: "settings_language_darkmode"
dueDate: null
created: "2026-09-05T01:07:26+07:00"
modified: "2026-09-05T01:25:00+07:00"
completedAt: "2026-09-05T01:25:00+07:00"
labels: ["settings", "presentation", "mvi", "viewmodel"]
order: "a4"
---

# Task 4: Settings Presentation Layer & MVI ViewModel

## Epic Reference
Epic: [settings_language_darkmode](../epic/settings_language_darkmode/settings_language_darkmode.en.md)

## Requirement Analysis
The Presentation layer of `Features/Settings` uses MVI (`Framework.MviViewModel`). It coordinates UI interactions, dispatches actions, and binds to `AppThemeManager` and `AppLocalizationManager`.

1. **`SettingsAction` (`Sources/Settings/Presentation/SettingsAction.swift`)**:
   - Add `.toggleDeveloperMode(Bool)`
   - Add `.showLanguagePicker(Bool)`
   - Retain `.onAppear`, `.toggleDarkMode`, `.selectLanguage`, `.toggleNotifications`.
2. **`SettingsState` (`Sources/Settings/Presentation/SettingsState.swift`)**:
   - Add `isLoadingLanguage: Bool = false`
   - Add `isLanguagePickerPresented: Bool = false`
   - Add `isDeveloperModeEnabled: Bool = false`
   - Add `appVersion: String` and `buildNumber: String`.
3. **`SettingsViewModel` (`Sources/Settings/Presentation/SettingsViewModel.swift`)**:
   - Injects `AppThemeManager`, `AppLocalizationManager`, `ChangeLanguageUseCase`, `GetAvailableLanguagesUseCase`, `SaveSettingsUseCase`.
   - On `.onAppear`: Loads settings, available languages, and bundle app version.
   - On `.toggleDarkMode`:
     - Optimistic toggle of `settings.isDarkMode`.
     - Calls `themeManager.setMode(isDarkMode ? .dark : .light)`.
     - Executes background sync via `UpdateUserPreferencesUseCase`.
   - On `.selectLanguage(code)`:
     - Uses `launch("changeLanguage")` which cancels any previous in-flight task (PR #34 race condition protection).
     - Delegates to `ChangeLanguageUseCase`, managing `isLoadingLanguage` and `isLanguagePickerPresented = false`.
     - On error, emits `.showError(message)`.
   - On `.showLanguagePicker(isPresented)`:
     - Sets `isLanguagePickerPresented = isPresented`.

## Relevant Files & Context Pointers
- `Features/Settings/Sources/Settings/Presentation/SettingsAction.swift`
- `Features/Settings/Sources/Settings/Presentation/SettingsState.swift`
- `Features/Settings/Sources/Settings/Presentation/SettingsEvent.swift`
- `Features/Settings/Sources/Settings/Presentation/SettingsViewModel.swift`
- `Features/Settings/Tests/SettingsTests/SettingsViewModelTests.swift`

## Design Rationale
Structured Concurrency within `MviViewModel.launch` ensures that rapid taps cancel superseded network tasks before they can mutate state out-of-order. Optimistic updates keep the UI responsive while background tasks ensure eventual server consistency.

## TDD Checklist
- [ ] **RED**: Write failing unit tests in `Features/Settings/Tests/SettingsTests/SettingsViewModelTests.swift`:
  - Test `.toggleDarkMode` immediately updates `isDarkMode` and calls `AppThemeManager`.
  - Test `.selectLanguage` with cached language updates state immediately.
  - Test `.selectLanguage` with un-cached language sets `isLoadingLanguage = true` until completion.
  - Test rapid `.selectLanguage` calls cancel the prior task and keep the final selection.
  - Test `.showLanguagePicker` updates `isLanguagePickerPresented`.
- [ ] **GREEN**: Update `SettingsAction`, `SettingsState`, and `SettingsViewModel` implementation.
  - Verify all tests pass with `swift test --package-path Features/Settings`.
- [ ] **REFACTOR**: Verify effect cancellation semantics and zero memory leaks upon teardown.

## Definition of Done (DoD)
- All ViewModel unit tests pass.
- Zero ArchTests violations (K2: Presentation never imports Data layer).

## Dependencies & Blockers
- Blocked by [Task 3](task_3_settings_domain_orchestration_usecases.md).

## References & Rollback
- Source Spec: [2026-09-05-settings-language-darkmode-design.md](../epic/settings_language_darkmode/2026-09-05-settings-language-darkmode-design.md)
- Rollback: Revert `Features/Settings/Sources/Settings/Presentation/` ViewModel edits.
