---
id: "task_4_core_logger_adapter"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T03:32:30+07:00"
modified: "2026-09-19T04:05:09+07:00"
completedAt: null
labels: ["architecture", "logging", "adapter", "compatibility", "memory-safety"]
order: "a4"
---

# Task 4: Core.Logger Backward-Compatibility Adapter

Epic Reference: [pulse_logger](pulse_logger.en.md)

## Requirement Analysis
Create a backward-compatibility adapter implementing `Core.Logger` and routing all legacy `debug()`, `info()`, and `error()` invocations into `D3NexusLogger.getLogger("Core")`. Replace `ConsoleLogger.swift` at the Composition Root (`AppComposition.swift`), verifying that the adapter instance deallocates with zero retain cycles when released from containers or caller scopes.

## Relevant Files & Context Pointers
- `Packages/Core/Sources/Core/Logging/Logger.swift`
- `Packages/Logging/Sources/Logging/Adapter/D3NexusCoreLoggerAdapter.swift`
- `App/Sources/Composition/AppComposition.swift`
- `App/Sources/Composition/ConsoleLogger.swift`
- `App/Tests/AppTests/AppCompositionTests.swift`
- `Packages/Logging/Tests/LoggingTests/CoreLoggerAdapterTests.swift`
- `Packages/Logging/Tests/LoggingTests/TestSupport/MemoryLeakTestSupport.swift`

## Design Rationale
- `D3NexusCoreLoggerAdapter`: Conforms to `Core.Logger` and `@unchecked Sendable`. Maps `debug(_:file:function:line:)`, `info(_:file:function:line:)`, and `error(_:file:function:line:)` to `D3NexusLogger.getLogger("Core")`.
- `AppComposition.swift`: Bootstrap `D3NexusLogger` with `LogManagerImpl` and register `D3NexusCoreLoggerAdapter` in the Factory container as the implementation for `Core.Logger`.
- `ConsoleLogger.swift`: Deprecate or retire in favor of `D3NexusCoreLoggerAdapter`.
- Memory Safety: `trackForMemoryLeaks` verifies that `D3NexusCoreLoggerAdapter` deallocates cleanly without creating lingering container references.
Applicable Skills: `code-health-audit`, `architecture-audit`.

## Impact Analysis & Blast Radius
- **Target Files & Symbols**:
  - `D3NexusCoreLoggerAdapter` class
  - `AppComposition.swift` (wiring)
- **Downstream Callers**: All callers of `Container.shared.logger()` (e.g. `LoggingInterceptor`, `AuthTokenInterceptor`, `APIClient`).
- **Cross-Platform Bridges**: N/A.
- **Target Test Coverage Threshold**: $100\%$ line coverage on `D3NexusCoreLoggerAdapter`.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

```gherkin
[Tier A - Unit]
Scenario: Delegate Core.Logger debug calls to D3NexusLogger
  Given a D3NexusCoreLoggerAdapter instance initialized with a mock logger
  When adapter.debug("Cache miss", file: "CacheStore.swift", function: "get()", line: 42) is called
  Then the underlying logger receives debug message "Cache miss"
  And the metadata captures file "CacheStore.swift", function "get()", and line "42"

[Tier A - Unit]
Scenario: Assert clean deallocation of D3NexusCoreLoggerAdapter
  Given an allocated D3NexusCoreLoggerAdapter instance
  When the test scope terminates
  Then trackForMemoryLeaks verifies the adapter deallocates completely

[Tier C - Integration]
Scenario: Resolve Core.Logger from Factory Container and verify telemetry flow
  Given AppComposition bootstrapping D3NexusLogger with PulseAppender
  When an existing service resolves Container.shared.logger() and invokes info("User session started")
  Then the log record is received by PulseAppender with module "Core"
  And the existing host app tests pass without regressions
```

## Test & Verification Checklist
- [ ] **RED**: Write failing unit tests in `CoreLoggerAdapterTests.swift` verifying delegation of all three methods and clean deallocation.
- [ ] **GREEN**: Implement `D3NexusCoreLoggerAdapter.swift` and update `AppComposition.swift`.
- [ ] **REFACTOR**: Run `swift test --package-path Packages/Logging` and `swift test --package-path Packages/Core`, format code, and verify zero warnings.

## Definition of Done (DoD)
- `D3NexusCoreLoggerAdapter` delegates cleanly to `D3NexusLogger`.
- `AppCompositionTests` pass 100% with zero memory leaks.
- Zero broken imports or AST boundary violations.

## Dependencies & Blockers
- Blocked by: [Task 2](task_2_log_manager_and_facade.md), [Task 3](task_3_swift_log_and_pulse_appenders.md).
- Blocks: [Task 5](task_5_network_trace_interceptor.md), [Task 7](task_7_acceptance_and_governance.md).

## References & Rollback
- References: `App/Sources/Composition/ConsoleLogger.swift`.
- Rollback: Revert `AppComposition.swift` to use `ConsoleLogger`.
