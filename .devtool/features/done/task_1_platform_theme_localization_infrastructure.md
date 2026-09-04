---
id: "task_1_platform_theme_localization_infrastructure"
status: "done"
priority: "high"
assignee: null
epic: "settings_language_darkmode"
dueDate: null
created: "2026-09-05T01:07:26+07:00"
modified: "2026-09-05T01:13:20+07:00"
completedAt: "2026-09-05T01:13:20+07:00"
labels: ["platform", "theme", "localization", "infrastructure"]
order: "a1"
---

# Task 1: Platform Theme & Localization Infrastructure

## Epic Reference
Epic: [settings_language_darkmode](../epic/settings_language_darkmode/settings_language_darkmode.en.md)

## Requirement Analysis
The application needs cross-feature state managers for theming (Dark/Light/System) and dynamic localization (OTA translations dictionary) living in `Packages/Platform`, the governed cross-feature seam of the iOS Super App template.

1. **`AppThemeMode` & `AppThemeManager`**:
   - `AppThemeMode`: enum with cases `.system`, `.light`, `.dark`.
   - `AppThemeManager`: `@MainActor public final class AppThemeManager: ObservableObject`.
   - Persists user selection using `Core.CacheStore` (key `"app_theme_mode"`).
   - Exposes computed `colorScheme: ColorScheme?` (`nil` for `.system`, `.dark` for `.dark`, `.light` for `.light`).
   - Emits `ThemeModeChanged(mode:)` to `AppEventBus`.
2. **`AppLocalizationManager`**:
   - `@MainActor public final class AppLocalizationManager: ObservableObject`.
   - Holds `@Published public private(set) var currentLanguageCode: String`.
   - Maintains in-memory dictionary `dynamicOverrides: [String: String]` loaded from disk cache.
   - Provides `func translate(_ key: String, default defaultString: String? = nil) -> String` implementing the two-tier lookup:
     1. Check dynamic dictionary.
     2. Fallback to `Bundle.main.localizedString(forKey:value:table:)` / `.xcstrings`.
     3. Fallback to `defaultString ?? key`.
   - Emits `AppLanguageChanged(languageCode:)` to `AppEventBus`.
3. **`AppEvent` additions**:
   - Define `ThemeModeChanged` and `AppLanguageChanged` conforming to `AppEvent`.

## Relevant Files & Context Pointers
- `Packages/Platform/Sources/Platform/Events/AppEvent.swift`
- `Packages/Platform/Sources/Platform/Theme/AppThemeMode.swift`
- `Packages/Platform/Sources/Platform/Theme/AppThemeManager.swift`
- `Packages/Platform/Sources/Platform/Localization/AppLocalizationManager.swift`
- `Packages/Platform/Tests/PlatformTests/AppThemeManagerTests.swift`
- `Packages/Platform/Tests/PlatformTests/AppLocalizationManagerTests.swift`

## Design Rationale
Placing `AppThemeManager` and `AppLocalizationManager` in `Packages/Platform` keeps `Packages/Core` framework-agnostic (Core depends only on Swift stdlib), while allowing `Features/Settings`, `Packages/Shell`, and `App` to observe theme and localization changes via `@EnvironmentObject` and `AppEventBus`.

## TDD Checklist
- [x] **RED**: Write failing tests in `Packages/Platform/Tests/PlatformTests/`:
  - `AppThemeManagerTests`: Test initial mode loading from cache, mode update persistence, and event bus broadcast.
  - `AppLocalizationManagerTests`: Test locale switching, dynamic translation dictionary application, lookup hierarchy fallback, and event bus broadcast.
- [x] **GREEN**: Implement minimal code in `Packages/Platform`:
  - Define `ThemeModeChanged` and `AppLanguageChanged` in `AppEvent.swift`.
  - Implement `AppThemeMode` and `AppThemeManager`.
  - Implement `AppLocalizationManager`.
  - Verify all tests pass with `swift test --package-path Packages/Platform`.
- [x] **REFACTOR**: Ensure `@MainActor` thread safety, clean documentation comments, and 0 compiler warnings.

## Definition of Done (DoD)
- All unit tests in `Packages/Platform/Tests/PlatformTests` pass.
- Architecture tests `swift test --package-path ArchTests` pass with 0 boundary violations.

## Dependencies & Blockers
- None. This is the foundation task.

## References & Rollback
- Source Spec: [2026-09-05-settings-language-darkmode-design.md](../epic/settings_language_darkmode/2026-09-05-settings-language-darkmode-design.md)
- Rollback: Revert commits modifying `Packages/Platform`.
