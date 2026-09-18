---
id: "task_6_pulse_ui_and_settings"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T03:32:30+07:00"
modified: "2026-09-19T03:32:30+07:00"
completedAt: null
labels: ["ui", "pulseui", "settings", "developer-tools"]
order: "a6"
---

# Task 6: PulseUI In-App Console & Developer Settings Toggles

Epic Reference: [pulse_logger](../epic/pulse_logger/pulse_logger.en.md)

## Requirement Analysis
Integrate `PulseUI` into the host application and provide runtime toggle controls. Implement a Shake Gesture recognizer in the host UI layer to summon the `PulseUI.ConsoleView` sheet at any time. In `Features/Settings`, introduce a Diagnostics / Developer Tools section (active only under `#if DEBUG`) allowing developers to toggle individual module mutes and appender kill-switches, persisted in `UserDefaults`.

## Relevant Files & Context Pointers
- `App/Sources/App.swift` or main view hierarchy
- `App/Sources/UI/ShakeGestureModifier.swift`
- `Features/Settings/Sources/Settings/Presentation/SettingsView.swift`
- `Features/Settings/Sources/Settings/Presentation/Diagnostics/LoggingDiagnosticsView.swift`
- `Features/Settings/Tests/SettingsTests/LoggingDiagnosticsViewModelTests.swift`

## Design Rationale
- `PulseUI`: Added as a dependency to `App` for `#if DEBUG` builds.
- Shake Gesture: A custom SwiftUI ViewModifier `.onShake { isConsolePresented = true }` that listens to `UIDevice.deviceDidShakeNotification` via `NotificationCenter`.
- Developer Settings:
  - Module Toggles: Switches for known modules (`Wallet`, `Network`, `Settings`, `Scanner`, `Core`). Mutating a switch invokes `D3NexusLogger.setModuleEnabled(module, enabled)` and persists the dictionary into `UserDefaults.standard` under key `logging.module_toggles`.
  - Appender Toggles: Switches for `pulse` and `oslog`, persisted under `logging.appender_toggles`.
  - Shortcut buttons: "Open Pulse Console" and "Clear Logs".
- Compile-time isolation: All debug UI and gesture code is wrapped inside `#if DEBUG` blocks to guarantee zero binary impact in Release mode.
Applicable Skills: `ios-ui-audit`, `architecture-audit`.

## Impact Analysis & Blast Radius
- **Target Files & Symbols**:
  - `ShakeGestureModifier` ViewModifier
  - `LoggingDiagnosticsView` SwiftUI View
  - `SettingsView` (addition of diagnostics section)
- **Downstream Callers**: Host application presentation hierarchy.
- **Cross-Platform Bridges**: N/A.
- **Target Test Coverage Threshold**: $\ge 80\%$ line coverage on view model / toggle management logic.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

```gherkin
[Tier C - Integration]
Scenario: Present PulseUI ConsoleView sheet on device shake in DEBUG build
  Given the app running in DEBUG mode
  When the deviceDidShake notification is broadcast
  Then the state triggers presentation of the PulseUI ConsoleView sheet
  And the console displays current in-memory log records

[Tier A - Unit]
Scenario: Persist and apply module toggle changes from Settings
  Given the LoggingDiagnosticsViewModel loaded with initial toggles
  When the developer turns off the toggle for "Wallet"
  Then D3NexusLogger.setModuleEnabled("Wallet", false) is invoked
  And UserDefaults contains "Wallet": false under key "logging.module_toggles"

[Tier B - Governance]
Scenario: Verify PulseUI and diagnostics code are stripped in Release configuration
  Given a Release configuration build
  When inspecting compiled symbols of Features/Settings and App
  Then no debug sheet presentation or shake gesture handlers are linked into the binary
```

## Test & Verification Checklist
- [ ] **RED**: Write failing unit tests for `LoggingDiagnosticsViewModelTests.swift` validating toggle mutations and persistence.
- [ ] **GREEN**: Implement `ShakeGestureModifier.swift`, `LoggingDiagnosticsView.swift`, and wire into `SettingsView.swift`.
- [ ] **REFACTOR**: Ensure all debug code is wrapped in `#if DEBUG`, verify SwiftUI body re-evaluation efficiency, format, and run `swift test --package-path Features/Settings`.

## Definition of Done (DoD)
- Shake gesture brings up PulseUI console on iOS Simulator / Device in Debug.
- Module toggles persist across app restarts via `UserDefaults`.
- 100% stripped in Release builds.

## Dependencies & Blockers
- Blocked by: [Task 3](task_3_swift_log_and_pulse_appenders.md), [Task 4](task_4_core_logger_adapter.md).
- Blocks: [Task 7](task_7_acceptance_and_governance.md).

## References & Rollback
- References: `kean/PulseUI` documentation.
- Rollback: Remove `#if DEBUG` additions from `SettingsView.swift` and `App.swift`.
