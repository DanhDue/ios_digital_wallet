---
id: "task_3_swift_log_and_pulse_appenders"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T03:32:30+07:00"
modified: "2026-09-19T03:32:30+07:00"
completedAt: null
labels: ["architecture", "logging", "pulse", "swift-log"]
order: "a3"
---

# Task 3: SwiftLog & Pulse Integration with Dual Appenders

Epic Reference: [pulse_logger](pulse_logger.en.md)

## Requirement Analysis
Integrate `apple/swift-log` and `kean/Pulse` into the template's SPM and Tuist dependency graph. Implement the two concrete sinks (`PulseAppender` and `OSLogAppender`) and the `D3NexusLogHandler` bridge so any standard Apple `Logging.Logger` invocation routes through `LogManager`.

## Relevant Files & Context Pointers
- `Tuist/Package.swift`
- `Packages/Logging/Package.swift`
- `Packages/Logging/Sources/Logging/Appender/PulseAppender.swift`
- `Packages/Logging/Sources/Logging/Appender/OSLogAppender.swift`
- `Packages/Logging/Sources/Logging/Bridge/D3NexusLogHandler.swift`
- `Packages/Logging/Tests/LoggingTests/AppenderTests.swift`
- `Packages/Logging/Tests/LoggingTests/SwiftLogBridgeTests.swift`

## Design Rationale
- `Tuist/Package.swift` and `Packages/Logging/Package.swift`: Add `.package(url: "https://github.com/apple/swift-log.git", from: "1.6.2")` and `.package(url: "https://github.com/kean/Pulse.git", from: "5.1.4")`.
- `PulseAppender`: Maps `LogRecord` fields into `Pulse.LoggerStore` entries. Configured with `respectsModuleToggle = true` so local developer mutes keep `PulseUI` clean.
- `OSLogAppender`: Uses `os.Logger(subsystem:category:)`. Configured with `respectsModuleToggle = false` so system diagnostics are preserved.
- `D3NexusLogHandler`: Conforms to `Logging.LogHandler`, translating Apple Logging events into `LogRecord` and dispatching via `LogManager`.
Applicable Skills: `code-health-audit`, `architecture-audit`.

## Impact Analysis & Blast Radius
- **Target Files & Symbols**:
  - `PulseAppender` class
  - `OSLogAppender` class
  - `D3NexusLogHandler` struct
  - `Tuist/Package.swift` dependencies
- **Downstream Callers**: `AppComposition.swift` (bootstrapping appenders).
- **Cross-Platform Bridges**: N/A.
- **Target Test Coverage Threshold**: $\ge 85\%$ line coverage on appender mapping and bridge logic.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

```gherkin
[Tier A - Unit]
Scenario: Dispatch LogRecord to PulseAppender and store structured event
  Given an initialized PulseAppender attached to an in-memory LoggerStore
  When a LogRecord with message "User logged in" and metadata ["userId": "12345"] is appended
  Then LoggerStore records an event with matching message and metadata
  And the category matches the record module name

[Tier A - Unit]
Scenario: Dispatch LogRecord to OSLogAppender
  Given an OSLogAppender configured for subsystem "com.danhdue.iOSDigitalWallet"
  When a LogRecord is appended
  Then the message is formatted with "[traceId][spanId]" correlation prefix
  And no crash or buffer overflow occurs

[Tier A - Unit]
Scenario: Forward Apple swift-log call via D3NexusLogHandler to LogManager
  Given LoggingSystem bootstrapped with D3NexusLogHandler
  And an injected mock LogManager
  When Apple standard Logging.Logger("Auth").info("Token refreshed") is executed
  Then LogManager receives a LogRecord with level .info, module "Auth", and message "Token refreshed"
```

## Test & Verification Checklist
- [ ] **RED**: Write failing tests in `AppenderTests.swift` and `SwiftLogBridgeTests.swift` testing `PulseAppender`, `OSLogAppender`, and `D3NexusLogHandler`.
- [ ] **GREEN**: Implement minimal code in `PulseAppender.swift`, `OSLogAppender.swift`, and `D3NexusLogHandler.swift`.
- [ ] **REFACTOR**: Verify `tuist install` fetches packages cleanly, run `swift test --package-path Packages/Logging`, and verify SwiftLint cleanliness.

## Definition of Done (DoD)
- `Packages/Logging` builds cleanly with `apple/swift-log` and `kean/Pulse`.
- Unit tests verify mapping, formatting, and `D3NexusLogHandler` bridge.
- Zero AST rule violations.

## Dependencies & Blockers
- Blocked by: [Task 2](task_2_log_manager_and_facade.md).
- Blocks: [Task 4](task_4_core_logger_adapter.md), [Task 6](task_6_pulse_ui_and_settings.md).

## References & Rollback
- References: `apple/swift-log` docs, `kean/Pulse` docs.
- Rollback: Remove dependencies from `Packages/Logging/Package.swift` and revert appenders.
