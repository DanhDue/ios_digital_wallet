---
id: "task_3_settings_domain_orchestration_usecases"
status: "done"
priority: "high"
assignee: null
epic: "settings_language_darkmode"
dueDate: null
created: "2026-09-05T01:07:26+07:00"
modified: "2026-09-05T01:22:00+07:00"
completedAt: "2026-09-05T01:22:00+07:00"
labels: ["settings", "domain", "usecases", "race-condition", "pr34"]
order: "a3"
---

# Task 3: Settings Domain Layer & PR #34 Orchestration Use Cases

## Epic Reference
Epic: [settings_language_darkmode](../epic/settings_language_darkmode/settings_language_darkmode.en.md)

## Requirement Analysis
The Domain layer contains pure Swift business logic without UI frameworks (ArchTests K3). It must implement individual use cases and the core `ChangeLanguageUseCase` orchestrator mirroring PR #34 from the reference repository.

1. **Domain Entities (`Sources/Settings/Domain/Entity/`)**:
   - `AvailableLanguage`: `languageCode: String`, `languageName: String`, `isDefault: Bool`, `isActive: Bool`.
   - `TranslationOverride`: `version: String`, `translations: [String: String]`.
   - Update `SettingsEntity` to include `availableLanguages: [AvailableLanguage]`.
2. **SettingsRepository Protocol (`Sources/Settings/Domain/Repository/SettingsRepository.swift`)**:
   - Add contracts for available languages, cache verification, overrides fetching, and preference syncing.
3. **Use Cases (`Sources/Settings/Domain/UseCase/`)**:
   - `GetAvailableLanguagesUseCase`: Fetches available languages from repository, merging with default fallbacks (`en`, `vi`).
   - `CheckLanguageCachedUseCase`: Returns `Bool` indicating if translation data for `code` exists locally.
   - `GetDynamicLocalizationUseCase`: Queries remote overrides (with ETag & version), saves cache, and applies to `AppLocalizationManager`.
   - `UpdateUserPreferencesUseCase`: Calls repository to update `selected_language` and/or `selected_theme_id`.
   - `ChangeLanguageUseCase`: Orchestrates the language switch workflow:
     - **Same Language**: If `code == currentLocale`, returns immediately (no-op).
     - **Cached / Bundled**: Applies optimistic locale switch immediately via `AppLocalizationManager.setLocale(code:)`, then fetches remote updates and syncs backend preference in the background.
     - **Not Cached**: Instructs caller to show loading state, fetches remote translations first, saves to cache, applies locale, updates user preference, and clears loading. On failure, aborts switch, keeps previous locale, and returns error state.

## Relevant Files & Context Pointers
- `Features/Settings/Sources/Settings/Domain/Entity/SettingsEntity.swift`
- `Features/Settings/Sources/Settings/Domain/Entity/AvailableLanguage.swift`
- `Features/Settings/Sources/Settings/Domain/Entity/TranslationOverride.swift`
- `Features/Settings/Sources/Settings/Domain/Repository/SettingsRepository.swift`
- `Features/Settings/Sources/Settings/Domain/UseCase/GetAvailableLanguagesUseCase.swift`
- `Features/Settings/Sources/Settings/Domain/UseCase/CheckLanguageCachedUseCase.swift`
- `Features/Settings/Sources/Settings/Domain/UseCase/GetDynamicLocalizationUseCase.swift`
- `Features/Settings/Sources/Settings/Domain/UseCase/UpdateUserPreferencesUseCase.swift`
- `Features/Settings/Sources/Settings/Domain/UseCase/ChangeLanguageUseCase.swift`
- `Features/Settings/Tests/SettingsTests/ChangeLanguageUseCaseTests.swift`
- `Features/Settings/Tests/SettingsTests/UseCaseTests.swift`

## Design Rationale
Pure Swift domain layer (no SwiftUI / UIKit / Combine imports). Encapsulates complex language switching logic inside `ChangeLanguageUseCase` so `SettingsViewModel` remains thin and declarative.

## TDD Checklist
- [ ] **RED**: Write comprehensive unit tests in `Features/Settings/Tests/SettingsTests/ChangeLanguageUseCaseTests.swift`:
  - Test selecting the current language returns without executing network calls.
  - Test cached language triggers immediate optimistic locale switch and background preference sync.
  - Test un-cached language triggers loading, downloads translations first, and only switches locale on success.
  - Test un-cached language network error keeps prior locale and emits failure without updating preferences.
- [ ] **GREEN**: Implement minimal code:
  - Create domain entities and repository protocol contracts.
  - Implement use cases and `ChangeLanguageUseCase`.
  - Verify all tests pass with `swift test --package-path Features/Settings`.
- [ ] **REFACTOR**: Ensure all methods are clean, well-documented, and adhere to Swift 6 concurrency rules.

## Definition of Done (DoD)
- 100% test coverage on `ChangeLanguageUseCase` scenarios.
- ArchTests K3 (no UI frameworks in Domain) passes cleanly.

## Dependencies & Blockers
- Blocked by [Task 1](task_1_platform_theme_localization_infrastructure.md) and [Task 2](task_2_settings_data_layer_api_integration.md).

## References & Rollback
- Source Spec: [2026-09-05-settings-language-darkmode-design.md](../epic/settings_language_darkmode/2026-09-05-settings-language-darkmode-design.md)
- Flutter PR #34: `epic/settings-bugfixes` (`ChangeLanguageUseCase.dart`).
- Rollback: Revert `Features/Settings/Sources/Settings/Domain/` changes.
