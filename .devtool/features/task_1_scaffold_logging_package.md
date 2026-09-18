---
id: "task_1_scaffold_logging_package"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T03:32:30+07:00"
modified: "2026-09-19T03:32:30+07:00"
completedAt: null
labels: ["architecture", "logging", "package"]
order: "a1"
---

# Task 1: Package Scaffolding, Data Models & Trace Tree

Epic Reference: [pulse_logger](../epic/pulse_logger/pulse_logger.en.md)

## Requirement Analysis
Create the isolated local SPM package `Packages/Logging` to establish the core data models, W3C correlation identifiers, and trace tree reconstruction logic. This task creates the foundation of the logging system without external SDK dependencies, ensuring pure Swift data structures and deterministic unit test verification.

## Relevant Files & Context Pointers
- `Packages/Logging/Package.swift`
- `Packages/Logging/Sources/Logging/Model/LogLevel.swift`
- `Packages/Logging/Sources/Logging/Model/LogRecord.swift`
- `Packages/Logging/Sources/Logging/Trace/TraceNode.swift`
- `Packages/Logging/Sources/Logging/Trace/TraceTree.swift`
- `Packages/Logging/Tests/LoggingTests/LogRecordTests.swift`
- `Packages/Logging/Tests/LoggingTests/TraceTreeTests.swift`

## Design Rationale
Mirroring Flutter's `packages/logger/lib/src/log_record.dart` and `trace_tree.dart`:
- `LogLevel`: Enum (`verbose`, `debug`, `info`, `warning`, `error`) conforming to `Comparable`, `Sendable`, and `Codable`.
- `LogRecord`: Immutable struct carrying `module`, `level`, `message`, `timestamp`, `traceId` (32 hex characters), `spanId` (16 hex characters), `parentSpanId`, `errorDescription`, and `metadata`.
- `buildTraceTree([LogRecord]) -> [TraceNode]`: A pure, side-effect-free function that converts a list of log records into a hierarchical forest of `TraceNode`s based on `parentSpanId -> spanId` matching. It guarantees zero data loss by promoting orphan records to root nodes.
Applicable Skills: `code-health-audit`, `architecture-audit`.

## Impact Analysis & Blast Radius
- **Target Files & Symbols**:
  - `LogLevel` enum
  - `LogRecord` struct
  - `TraceNode` class
  - `buildTraceTree` function
- **Downstream Callers**: `LogManager`, `PulseAppender`, `OSLogAppender` (implemented in later tasks).
- **Cross-Platform Bridges**: N/A.
- **Target Test Coverage Threshold**: $\ge 95\%$ line coverage on `Packages/Logging/Sources/Logging/Model` and `Trace`.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

```gherkin
[Tier A - Unit]
Scenario: Create immutable LogRecord with valid W3C identifiers
  Given a valid module name "Wallet" and level .info
  When a LogRecord is instantiated with traceId "4bf92f3577b34da6a3ce929d0e0e4736", spanId "00f067aa0ba902b7", and message "Balance loaded"
  Then the LogRecord properties match the provided inputs
  And the parentSpanId is nil
  And the timestamp is set to the current date

[Tier A - Unit]
Scenario: Reconstruct hierarchical tree from ordered parent-child records
  Given a list of 3 log records with sequential parent-child relationships:
    | ID | SpanId | ParentSpanId | Message |
    | 1  | span_A | nil          | Root operation |
    | 2  | span_B | span_A       | Child operation 1 |
    | 3  | span_C | span_B       | Grandchild operation |
  When buildTraceTree is executed with this list
  Then the result contains exactly 1 root TraceNode corresponding to ID 1
  And root node ID 1 contains 1 child corresponding to ID 2
  And child node ID 2 contains 1 child corresponding to ID 3

[Tier A - Unit]
Scenario: Handle orphan records gracefully without dropping data
  Given a list of 2 log records:
    | ID | SpanId | ParentSpanId | Message |
    | 1  | span_X | span_MISSING | Orphan step |
    | 2  | span_Y | nil          | Normal root |
  When buildTraceTree is executed with this list
  Then the result contains 2 root TraceNodes
  And the orphan record is retained as a root node
  And zero records are lost

[Tier A - Unit]
Scenario: Handle duplicate spanIds safely
  Given multiple log records emitted with the identical spanId "span_SAME"
  When buildTraceTree is executed
  Then all records are retained in the output tree
```

## Test & Verification Checklist
- [ ] **RED**: Write failing unit tests in `Packages/Logging/Tests/LoggingTests/LogRecordTests.swift` and `TraceTreeTests.swift` covering all BDD scenarios.
- [ ] **GREEN**: Implement minimal code in `LogLevel.swift`, `LogRecord.swift`, `TraceNode.swift`, and `TraceTree.swift` to pass tests.
- [ ] **REFACTOR**: Ensure Swift 6 `Sendable` conformance, format (`swiftformat .`), lint (`swiftlint lint --strict`), and verify tests pass with `swift test --package-path Packages/Logging`.

## Definition of Done (DoD)
- `Packages/Logging` builds cleanly with Swift 6 compiler.
- 100% of BDD unit test scenarios pass via `swift test --package-path Packages/Logging`.
- Zero compiler warnings, 100% SwiftLint and SwiftFormat clean.

## Dependencies & Blockers
- Blocked by: None.
- Blocks: [Task 2](task_2_log_manager_and_facade.md).

## References & Rollback
- References: W3C Trace Context Specification (<https://www.w3.org/TR/trace-context/>).
- Rollback: Delete directory `Packages/Logging`.
