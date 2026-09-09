---
id: "task_6_root_composition_app_wiring"
status: "done"
priority: "high"
assignee: null
epic: "settings_language_darkmode"
dueDate: null
created: "2026-09-05T01:07:26+07:00"
modified: "2026-09-05T01:33:30+07:00"
completedAt: "2026-09-05T01:33:30+07:00"
labels: ["app", "composition", "shell", "e2e", "archtests"]
order: "a6"
---

# Task 6: Root Composition & App-Wide Wiring Verification

## Epic Reference
Epic: [settings_language_darkmode](../epic/settings_language_darkmode/settings_language_darkmode.en.md)

## Requirement Analysis
The final task ties all components together at the app composition root, applies the theme mode to the entire window hierarchy, and validates end-to-end functionality.

1. **`AppComposition.swift` (`App/Sources/Composition/`)**:
   - Instantiate `AppThemeManager(cache: cache, eventBus: eventBus)`.
   - Instantiate `AppLocalizationManager(cache: cache, eventBus: eventBus)`.
   - Pass both managers and `apiClient` to `SettingsModule.makeRouteProvider(...)`.
   - Expose `themeManager` and `localizationManager` for root view binding.
2. **`RootView.swift` (`App/Sources/`)**:
   - Observe `AppThemeManager` and apply `.preferredColorScheme(themeManager.colorScheme)`.
   - Inject `.environmentObject(themeManager)` and `.environmentObject(localizationManager)`.
3. **`SettingsModule.swift` (`Features/Settings/Sources/Settings/`)**:
   - Update factory methods to accept `AppThemeManager`, `AppLocalizationManager`, and `APIClient`.
4. **Validation & Verification**:
   - Run unit test suites across all packages.
   - Run `swift test --package-path ArchTests` to verify AST rules K1–K9 remain clean.
   - Validate that switching theme immediately toggles light/dark mode throughout the app.
   - Validate that switching language updates text across the Settings screen.

## Relevant Files & Context Pointers
- `App/Sources/Composition/AppComposition.swift`
- `App/Sources/RootView.swift`
- `Features/Settings/Sources/Settings/SettingsModule.swift`
- `ArchTests/Tests/ArchTests/`

## Design Rationale
In keeping with the template's governance, the host app composition root (`App/`) is the ONLY place where features and global infrastructure are wired together. Neither `Shell` nor individual features know about other features or the concrete composition setup.

## TDD Checklist
- [ ] **RED**: Write integration tests in `Features/Settings/Tests/SettingsTests/SettingsRouteProviderTests.swift` checking module factory builds a ViewModel wired to both managers and repository.
- [ ] **GREEN**: Wire `AppThemeManager` and `AppLocalizationManager` in `AppComposition`, `SettingsModule`, and `RootView`.
  - Verify app builds and runs without errors.
- [ ] **REFACTOR**: Ensure no retain cycles between composition root, managers, and view models. Run SwiftLint and SwiftFormat if applicable.

## Definition of Done (DoD)
- Full app compiles cleanly.
- All package tests pass (`swift test --package-path Packages/Platform`, `swift test --package-path Features/Settings`).
- `swift test --package-path ArchTests` passes with 0 failures and 0 warnings.

## Dependencies & Blockers
- Blocked by [Task 1](task_1_platform_theme_localization_infrastructure.md), [Task 2](task_2_settings_data_layer_api_integration.md), [Task 3](task_3_settings_domain_orchestration_usecases.md), [Task 4](task_4_settings_presentation_mvi_viewmodel.md), and [Task 5](task_5_settings_card_ui_language_bottom_sheet.md).

## References & Rollback
- Source Spec: [2026-09-05-settings-language-darkmode-design.md](../epic/settings_language_darkmode/2026-09-05-settings-language-darkmode-design.md)
- Rollback: Revert wiring in `App/` and `SettingsModule.swift`.
