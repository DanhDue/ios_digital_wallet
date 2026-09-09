---
id: "task_2_settings_data_layer_api_integration"
status: "done"
priority: "high"
assignee: null
epic: "settings_language_darkmode"
dueDate: null
created: "2026-09-05T01:07:26+07:00"
modified: "2026-09-05T01:19:00+07:00"
completedAt: "2026-09-05T01:19:00+07:00"
labels: ["settings", "data", "networking", "cache"]
order: "a2"
---

# Task 2: Settings Data Layer & API Client Integration

## Epic Reference
Epic: [settings_language_darkmode](../epic/settings_language_darkmode/settings_language_darkmode.en.md)

## Requirement Analysis
The `Features/Settings` Data layer needs remote networking and local caching to support available languages, translation overrides, and user preferences synchronization.

1. **DTOs (`Sources/Settings/Data/Model/`)**:
   - `AvailableLanguageDTO`: `language_code`, `language_name`, `is_default`, `is_active`.
   - `TranslationOverrideDTO`: `version`, `translations: [String: String]` (or nested dictionary flattener), `mode` (`full` / `delta`).
   - `UserPreferencesDTO`: `selected_language`, `selected_theme_id`.
2. **`SettingsRemoteDataSource` (`Sources/Settings/Data/Remote/`)**:
   - Uses `Network.APIClient` to perform:
     - `GET /api/v1/translations` -> returns `[AvailableLanguageDTO]`.
     - `GET /api/v1/translations/{code}?since_version={version}` with header `If-None-Match: {eTag}` -> returns `TranslationOverrideDTO?`. Handles HTTP 304 by returning `nil` (indicating no change).
     - `PUT /api/v1/users/me/preferences` with body `{"selected_language": "...", "selected_theme_id": "..."}`.
3. **`SettingsLocalDataSource` (`Sources/Settings/Data/Local/`)**:
   - Stores cached translations JSON per language code using `Core.CacheStore`.
   - Stores cached version string and ETag checksum per language code.
   - Stores cached `AvailableLanguage` list.
4. **`SettingsRepositoryImpl` (`Sources/Settings/Data/Repository/`)**:
   - Implements updated `SettingsRepository` protocol methods connecting local and remote data sources.

## Relevant Files & Context Pointers
- `Packages/Network/Sources/Network/APIClient.swift`
- `Packages/Network/Sources/Network/Response/BaseResponseObject.swift`
- `Features/Settings/Sources/Settings/Data/Model/SettingsDTO.swift`
- `Features/Settings/Sources/Settings/Data/Local/SettingsLocalDataSource.swift`
- `Features/Settings/Sources/Settings/Data/Remote/SettingsRemoteDataSource.swift`
- `Features/Settings/Sources/Settings/Data/Repository/SettingsRepositoryImpl.swift`
- `Features/Settings/Tests/SettingsTests/SettingsRepositoryImplTests.swift`

## Design Rationale
Per ArchTests K4, all concrete declarations in `Data/` remain `internal` (only exposed through Domain protocols). `Network.APIClient` is injected into `SettingsRemoteDataSource` enabling clean unit testing via `MockAPIClient`.

## TDD Checklist
- [ ] **RED**: Write failing tests in `Features/Settings/Tests/SettingsTests/`:
  - `SettingsRemoteDataSourceTests`: Test endpoint URL paths, query parameters, ETag header injection, and 304 Not Modified mapping.
  - `SettingsLocalDataSourceTests`: Test caching of translations JSON, versions, and language lists.
  - `SettingsRepositoryImplTests`: Test remote fetch with local cache fallback and preference save.
- [ ] **GREEN**: Implement minimal code:
  - Create DTOs with `Codable` and `Sendable`.
  - Implement `SettingsRemoteDataSource` with `APIRequest`.
  - Extend `SettingsLocalDataSource` with translation cache slots.
  - Implement `SettingsRepositoryImpl`.
  - Verify all tests pass with `swift test --package-path Features/Settings`.
- [ ] **REFACTOR**: Remove duplication, optimize JSON decoding/flattening, verify memory efficiency.

## Definition of Done (DoD)
- Unit tests cover 100% of the new Data layer methods.
- ArchTests K4 (Data layer internal only) and K1-K3 pass cleanly.

## Dependencies & Blockers
- Blocked by [Task 1](task_1_platform_theme_localization_infrastructure.md) for event and manager dependencies.

## References & Rollback
- Source Spec: [2026-09-05-settings-language-darkmode-design.md](../epic/settings_language_darkmode/2026-09-05-settings-language-darkmode-design.md)
- Rollback: Revert `Features/Settings/Sources/Settings/Data/` changes.
