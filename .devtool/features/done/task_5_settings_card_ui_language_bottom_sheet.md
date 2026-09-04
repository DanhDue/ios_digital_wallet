---
id: "task_5_settings_card_ui_language_bottom_sheet"
status: "done"
priority: "high"
assignee: null
epic: "settings_language_darkmode"
dueDate: null
created: "2026-09-05T01:07:26+07:00"
modified: "2026-09-05T01:28:00+07:00"
completedAt: "2026-09-05T01:28:00+07:00"
labels: ["settings", "ui", "swiftui", "bottomsheet"]
order: "a5"
---

# Task 5: Settings Card UI & Language Bottom Sheet

## Epic Reference
Epic: [settings_language_darkmode](../epic/settings_language_darkmode/settings_language_darkmode.en.md)

## Requirement Analysis
Transform `SettingsView` into the card-based design matching the reference Flutter screenshots and implement `LanguagePickerBottomSheet`.

1. **Card Layout & Structure**:
   - Background: `Color.appBackground` with scrollable grouped cards.
   - Section headers in uppercase gray caption style (`TÀI KHOẢN`, `TÙY CHỌN`, `NHÀ PHÁT TRIỂN`, `THÔNG TIN ỨNG DỤNG`).
   - Card container: White/surface background (`Color.appSurface`), rounded corners (`cornerRadius: 16`), subtle dividers between rows.
2. **Settings Item Components (`SettingsItemRow`)**:
   - Colored circular icon badge on the leading side.
   - Title text.
   - Trailing indicators:
     - Chevron for navigation rows (Profile, Change Password, Contact Support).
     - Tag label + Chevron for 2FA (`"Bật"` in green).
     - Value + Chevron for Currency (`"USD ($)"`) and Language (e.g. `"Tiếng Việt"`).
     - Toggle switch for Dark Mode and Debug Mode.
     - Plain text value for About App (`"1.0.0"`).
3. **Logout Button**:
   - Standalone rounded card button at the bottom with red text and icon: `[-> Đăng xuất`.
4. **Modal Language Bottom Sheet (`LanguagePickerBottomSheet.swift`)**:
   - Triggered by tapping the "Language" row (or when `isLanguagePickerPresented` is true).
   - Displayed via `.sheet` with `.presentationDetents([.medium, .large])` and drag indicator.
   - Bold centered header: `"Ngôn ngữ"`.
   - List of available languages (`English (US)`, `Tiếng Việt`, `日本語`, `한국어`).
   - Checkmark icon (`✓` in blue) on the active language row.
   - Tapping an option dispatches `.selectLanguage(code)` and dismisses the sheet.

## Relevant Files & Context Pointers
- `Features/Settings/Sources/Settings/Presentation/SettingsView.swift`
- `Features/Settings/Sources/Settings/Presentation/Components/SettingsSectionCard.swift`
- `Features/Settings/Sources/Settings/Presentation/Components/SettingsItemRow.swift`
- `Features/Settings/Sources/Settings/Presentation/Components/LanguagePickerBottomSheet.swift`
- `Features/Settings/Tests/SettingsTests/SettingsViewTests.swift`

## Design Rationale
Using clean, reusable SwiftUI subviews (`SettingsSectionCard`, `SettingsItemRow`, `LanguagePickerBottomSheet`) keeps `SettingsView` declarative and readable while delivering 100% fidelity to the visual reference.

## TDD Checklist
- [ ] **RED**: Write snapshot / view unit tests in `Features/Settings/Tests/SettingsTests/SettingsViewTests.swift`:
  - Test `SettingsView` renders card sections and items correctly.
  - Test tapping "Language" row triggers `.showLanguagePicker(true)`.
  - Test `LanguagePickerBottomSheet` renders available languages and indicates the active selection with a checkmark.
- [ ] **GREEN**: Implement UI components in `Features/Settings/Sources/Settings/Presentation/`:
  - Implement `SettingsItemRow` with icon badges and trailing types.
  - Implement `SettingsSectionCard`.
  - Implement `LanguagePickerBottomSheet`.
  - Rebuild `SettingsView.body` with the new components.
  - Verify all tests pass with `swift test --package-path Features/Settings`.
- [ ] **REFACTOR**: Ensure proper spacing tokens from `AppUIKit`, correct accessibility labels, and dynamic color scheme resolution.

## Definition of Done (DoD)
- UI visually matches the provided screenshots.
- All view tests in `SettingsViewTests` pass.

## Dependencies & Blockers
- Blocked by [Task 4](task_4_settings_presentation_mvi_viewmodel.md).

## References & Rollback
- Source Spec: [2026-09-05-settings-language-darkmode-design.md](../epic/settings_language_darkmode/2026-09-05-settings-language-darkmode-design.md)
- User screenshots from chat conversation.
- Rollback: Revert UI changes to `SettingsView.swift`.
