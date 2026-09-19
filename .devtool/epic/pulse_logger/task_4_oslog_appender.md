---
id: "task_4_oslog_appender"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T04:47:44+07:00"
modified: "2026-09-19T04:47:44+07:00"
completedAt: null
labels: ["logging", "appender", "oslog", "memory-safety"]
order: "a4"
---

# Task 4: OSLogAppender & Toggle Persistence Wiring

Epic: [pulse_logger](pulse_logger.en.md) · BDD: [bdd_scenarios.md](bdd_scenarios.md) UC-1, UC-4

## Requirement Analysis

Implement the first concrete sink: `OSLogAppender`, forwarding sanitised `LogRecord`s to Apple
Unified Logging so they reach Console.app, the Xcode console and `sysdiagnose`. It sets
`respectsModuleToggle = false` — a developer muting a noisy module in the in-app console must not
thereby blind production diagnostics.

This appender is deliberately the one that lives **inside** the package and carries no third-party
dependency. It is the fallback the rollout strategy relies on: if Pulse misbehaves, system telemetry
is unaffected because it does not share a package with it (HLD §6, D5).

## Relevant Files & Context Pointers

- `Packages/D3NexusLogging/Sources/D3NexusLogging/Appender/OSLogAppender.swift` — create
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Manager/ToggleStore.swift` — modify if the
  persistence seam needs widening for the appender id
- `Packages/D3NexusLogging/Tests/D3NexusLoggingTests/OSLogAppenderTests.swift` — create
- Read and preserve the behaviour of: `App/Sources/Composition/ConsoleLogger.swift` — the existing
  `os.Logger` wrapper this eventually replaces, including its `@unchecked Sendable` rationale and
  its `privacy: .public` choice

## Design Rationale

- **Subsystem is injected, with no app-derived default (extraction constraint E2).** `init` takes
  `subsystem: String` as a required parameter. It must **not** default to this app's bundle
  identifier: a consumer of the extracted SDK has its own subsystem, and a silent default would
  publish their logs under our name. The composition root in Task 6 supplies it. Category comes from
  `LogRecord.module`, so Console.app filtering by module works without string surgery (HLD §3.2).
- **Correlation prefix**: messages are emitted as `[traceId][spanId] message`, which is what makes a
  `sysdiagnose` capture joinable with backend APM traces carrying the same `traceparent`.
- **Privacy annotation**: `ConsoleLogger` currently uses `privacy: .public`. That is correct only
  because records are already sanitised by Task 3's redactor before they reach any appender. This
  dependency is deliberate and must be stated in the doc comment — reordering the two would silently
  start publishing secrets to the unified log.
- **Level mapping**: `verbose`/`debug` → `os.Logger.debug`, `info` → `.info`, `warning` → `.warning`,
  `error` → `.error`.
- **Sendability**: the sole stored value is an `os.Logger`, itself `Sendable` and never reassigned —
  the same reasoning already documented in `ConsoleLogger`.

Applicable skills: `code-health-audit`, `architecture-audit`.

## Impact Analysis & Blast Radius

- **Target symbols**: `OSLogAppender`.
- **Downstream callers**: Task 6 registers it at the composition root.
- **Cross-platform bridges**: none.
- **Coverage threshold**: `Appender/**` ≥ 85% line. `os.Logger` output is not directly readable from
  a unit test, so assert on the formatting seam — inject the string-formatting step and verify the
  composed message, level mapping and category rather than attempting to read the unified log.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

Authoritative copies in [bdd_scenarios.md](bdd_scenarios.md). This task implements:

- **UC-1.1** — every severity reaches the appender at the mapped `os` level.
- **UC-4.1** — the `"oslog"` half of the dispatch truth table: dispatched when the module is muted
  (`respectsModuleToggle = false`), suppressed when the appender kill-switch is off.
- **UC-4.2** — the `"oslog"` kill-switch persists across a toggle-store rebuild.
- **UC-7.1** — the appender deallocates cleanly and does not retain the manager that registered it.

Plus, specific to this task:

```gherkin
[Tier A - Unit]
Scenario: The correlation prefix is present and well formed
  Given an OSLogAppender for subsystem "com.danhdue.iOSDigitalWallet"
  When a record with traceId T and spanId S is appended
  Then the composed message begins with "[T][S] "
  And the os category equals the record module
```

## Test & Verification Checklist

- [ ] **RED** — `OSLogAppenderTests` covering level mapping, category derivation, correlation prefix,
      and the `respectsModuleToggle = false` behaviour through `LogManagerImpl`.
- [ ] **GREEN** — implement `OSLogAppender`.
- [ ] **REFACTOR** — `swiftformat`; `swiftlint --strict`; confirm no `@unchecked Sendable` beyond the
      documented `os.Logger` case.
- [ ] **Verify** — `swift test --package-path Packages/D3NexusLogging` green with
      `trackForMemoryLeaks` on the appender.

## Definition of Done (DoD)

- The `"oslog"` rows of the dispatch truth table pass.
- Correlation prefix and category derivation covered by assertions.
- The redactor-before-appender ordering dependency is documented in the type's doc comment.
- `Appender/**` ≥ 85% line coverage.
- `trackForMemoryLeaks` green; SwiftLint and SwiftFormat clean.

## Dependencies & Blockers

- Blocked by: [Task 2](task_2_log_manager_and_facade.md), [Task 3](task_3_redactor_pii_masking.md).
- Blocks: [Task 6](task_6_graph_wiring_and_core_adapter.md).

## References & Rollback

- `os.Logger` — <https://developer.apple.com/documentation/os/logger>
- Rollback: delete `OSLogAppender.swift`. The manager dispatches to zero appenders, which is inert
  rather than broken.
