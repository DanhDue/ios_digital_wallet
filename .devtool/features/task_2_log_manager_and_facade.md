---
id: "task_2_log_manager_and_facade"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T03:32:30+07:00"
modified: "2026-09-19T04:05:09+07:00"
completedAt: null
labels: ["architecture", "logging", "dispatch", "facade", "memory-safety"]
order: "a2"
---

# Task 2: LogManager Dispatch Engine, LoggerProtocol & Facade

Epic Reference: [pulse_logger](../epic/pulse_logger/pulse_logger.en.md)

## Requirement Analysis
Implement the core dispatch engine (`LogManagerImpl`), the sink interface (`LogAppender`), the per-module logger (`LoggerProtocol` / `LoggerImpl`), and the static entry point (`D3NexusLogger`). This task enforces thread-safe dispatching across registered appenders, honors both module debug mutes and appender kill-switches, supports automatic parent-child span creation via `withSpan()`, and verifies zero retain cycles across the logger hierarchy using `trackForMemoryLeaks`.

## Relevant Files & Context Pointers
- `Packages/Logging/Sources/Logging/Appender/LogAppender.swift`
- `Packages/Logging/Sources/Logging/Manager/LogManager.swift`
- `Packages/Logging/Sources/Logging/Manager/LogManagerImpl.swift`
- `Packages/Logging/Sources/Logging/Logger/LoggerProtocol.swift`
- `Packages/Logging/Sources/Logging/Logger/LoggerImpl.swift`
- `Packages/Logging/Sources/Logging/Facade/D3NexusLogger.swift`
- `Packages/Logging/Tests/LoggingTests/LogManagerTests.swift`
- `Packages/Logging/Tests/LoggingTests/LoggerSpanTests.swift`
- `Packages/Logging/Tests/LoggingTests/TestSupport/MemoryLeakTestSupport.swift`

## Design Rationale
Mirroring Flutter's `LogManagerImpl`, `i_log_appender.dart`, and `i_logger.dart`:
- `LogAppender`: Protocol declaring `id: String`, `respectsModuleToggle: Bool`, and `append(_ record: LogRecord)`.
- `LogManager`: Protocol managing appenders, module toggles, and appender toggles.
- `LogManagerImpl`: Thread-safe coordinator using `os_unfair_lock` or `NSLock` ensuring zero data races under Swift 6 strict concurrency.
- `LoggerProtocol`: Declares `traceId`, `spanId`, `d/i/w/e/v` methods, and `withSpan() -> any LoggerProtocol`.
- `LoggerImpl`: Implements `LoggerProtocol`, auto-stamping new spans with parent linkage while storing only value-type trace IDs (zero strong reference to parent `LoggerImpl`, preventing circular retain cycles).
- `D3NexusLogger`: Static facade delegating to the injected `LogManager`.
Applicable Skills: `code-health-audit`, `architecture-audit`.

## Impact Analysis & Blast Radius
- **Target Files & Symbols**:
  - `LogAppender` protocol
  - `LogManager` protocol & `LogManagerImpl` class
  - `LoggerProtocol` protocol & `LoggerImpl` class
  - `D3NexusLogger` static enum facade
- **Downstream Callers**: All app modules, features, network interceptors.
- **Cross-Platform Bridges**: N/A.
- **Target Test Coverage Threshold**: $\ge 90\%$ line coverage on dispatch engine and span generation.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

```gherkin
[Tier A - Unit]
Scenario Outline: Verify dispatch matrix across Module Toggle and Appender Toggle combinations
  Given a mock appender with id <AppenderId> and respectsModuleToggle <RespectsToggle>
  And the appender kill-switch for <AppenderId> is <AppenderEnabled>
  And the module toggle for "Wallet" is <ModuleEnabled>
  When a log record for module "Wallet" is dispatched
  Then the appender receive count is <ExpectedDispatched>

  Examples:
    | AppenderId | RespectsToggle | AppenderEnabled | ModuleEnabled | ExpectedDispatched |
    | "pulse"    | true           | true            | true          | 1                  |
    | "pulse"    | true           | true            | false         | 0                  |
    | "pulse"    | true           | false           | true          | 0                  |
    | "pulse"    | true           | false           | false         | 0                  |
    | "oslog"    | false          | true            | true          | 1                  |
    | "oslog"    | false          | true            | false         | 1                  |
    | "oslog"    | false          | false           | true          | 0                  |
    | "oslog"    | false          | false           | false         | 0                  |

[Tier A - Unit]
Scenario: Spawn child span preserving traceId and setting parentSpanId
  Given a root logger with traceId "trace_ABC" and spanId "span_ROOT"
  When withSpan() is called on the root logger
  Then the returned child logger has traceId "trace_ABC"
  And the child logger has a new unique spanId
  And any record emitted by the child logger carries parentSpanId "span_ROOT"

[Tier A - Unit]
Scenario: Assert child loggers do not retain parent logger instance
  Given a parent LoggerImpl instance
  When childLogger = parentLogger.withSpan() is created
  And parentLogger is released
  Then trackForMemoryLeaks verifies parentLogger deallocates immediately
  And childLogger remains valid and operational

[Tier A - Unit]
Scenario: Thread-safe concurrent logging and toggle mutations
  Given 100 concurrent tasks logging via D3NexusLogger
  When toggles are mutated concurrently across multiple threads
  Then zero race condition crashes occur
  And internal lock preserves state integrity
```

## Test & Verification Checklist
- [ ] **RED**: Write failing tests in `LogManagerTests.swift` and `LoggerSpanTests.swift` validating the 8-case truth table, span hierarchy, and memory deallocation assertions.
- [ ] **GREEN**: Implement minimal code in `LogAppender.swift`, `LogManagerImpl.swift`, `LoggerImpl.swift`, and `D3NexusLogger.swift`.
- [ ] **REFACTOR**: Ensure Swift 6 `Sendable` discipline, format (`swiftformat .`), lint (`swiftlint lint --strict`), and execute `swift test --package-path Packages/Logging`.

## Definition of Done (DoD)
- 100% of dispatch matrix unit tests pass cleanly.
- `withSpan()` correctly links parent-child relationships across arbitrary nesting depths with zero memory leaks.
- Zero memory leaks, zero compiler warnings.

## Dependencies & Blockers
- Blocked by: [Task 1](task_1_scaffold_logging_package.md).
- Blocks: [Task 3](task_3_swift_log_and_pulse_appenders.md), [Task 4](task_4_core_logger_adapter.md).

## References & Rollback
- References: Flutter `packages/logger/lib/src/log_manager_impl.dart`.
- Rollback: Revert changes to `Packages/Logging/Sources/Logging/Manager` and `Logger`.
