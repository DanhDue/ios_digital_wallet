---
id: "task_5_swift_log_bridge"
status: "done"
priority: "medium"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T04:47:44+07:00"
modified: "2026-09-19T12:14:44Z"
completedAt: "2026-09-19T12:14:44Z"
labels: ["logging", "swift-log", "interoperability"]
order: "a5"
---

# Task 5: swift-log Bridge — `D3NexusLogHandler`

Epic: [pulse_logger](pulse_logger.en.md) · BDD: [bdd_scenarios.md](bdd_scenarios.md) UC-1

## Requirement Analysis

Add `apple/swift-log` to `Packages/D3NexusLogging` and implement `D3NexusLogHandler`, a
`Logging.LogHandler` that translates any standard swift-log event into a `LogRecord` and dispatches
it through `LogManager`. Provide the `LoggingSystem.bootstrap` entry point the composition root will
call in Task 6.

**Why this task is isolated**: it introduces the package's only remote dependency. Keeping it in its
own commit means the dependency can be reverted without unwinding the dispatch engine.

**Why the package is named `D3NexusLogging`**: swift-log's library product and module are both called
`Logging`. A local target of the same name depending on it is a SwiftPM duplicate-module error, and
every consumer's `import Logging` would be ambiguous. The rename performed in Task 1 is what makes
this task compile at all (HLD D1).

## Relevant Files & Context Pointers

- `Packages/D3NexusLogging/Package.swift` — **modify**: add
  `.package(url: "https://github.com/apple/swift-log.git", from: "1.6.2")` and the
  `.product(name: "Logging", package: "swift-log")` target dependency
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Bridge/D3NexusLogHandler.swift` — create
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Bridge/LoggingSystemBootstrap.swift` — create
- `Packages/D3NexusLogging/Tests/D3NexusLoggingTests/SwiftLogBridgeTests.swift` — create

## Design Rationale

- **Level mapping**: swift-log's `trace`/`debug`/`info`/`notice`/`warning`/`error`/`critical`
  collapses onto the five-level `LogLevel`. `trace` → `.verbose`; `notice` → `.info`;
  `critical` → `.error`. The mapping is lossy in one direction and must be documented, because a
  reader of the unified log cannot otherwise tell `error` from `critical`.
- **Trace identifiers**: if the incoming metadata carries `traceId` / `spanId`, honour them — that is
  how a third-party library participating in an existing span keeps its records joinable. Otherwise
  generate fresh ones through Task 1's `TraceIdentifier`. The spec's inline
  `String(UUID().uuidString.prefix(16))` fallback is not used anywhere: it produces a value
  containing `-` and fails the 16-hex contract (HLD D6).
- **`LogHandler` is a `struct` by protocol requirement** — swift-log copies handlers per logger, so
  the manager reference it holds must be a `Sendable` reference type. Confirm no per-copy state
  accumulates.
- **Bootstrap is explicit, not automatic.** `LoggingSystem.bootstrap` can be called exactly once per
  process; calling it from package initialisation would make test ordering fragile. Expose a
  function and let Task 6's composition root own the single call.
- **Scope honesty**: this repo's only third-party dependency today is `Factory`, which does not use
  swift-log, so the bridge has no current producer. It was kept deliberately at Gate 2 as
  future-proofing for libraries added later. Tests therefore drive it directly rather than through a
  real third-party emitter.

Applicable skills: `architecture-audit`, `code-health-audit`.

## Impact Analysis & Blast Radius

- **Target symbols**: `D3NexusLogHandler`, the bootstrap function, `Package.swift` dependencies.
- **Downstream callers**: Task 6 (composition root calls bootstrap).
- **New external dependency**: `apple/swift-log` — pure Swift, no transitive dependencies, supports
  the `.macOS(.v13)` host floor the CI package loop requires.
- **Cross-platform bridges**: none.
- **Coverage threshold**: `Bridge/**` ≥ 85% line, with the full level-mapping table covered.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

Authoritative copies in [bdd_scenarios.md](bdd_scenarios.md). This task implements UC-1.1's level
mapping through the bridge, plus:

```gherkin
[Tier A - Unit]
Scenario Outline: swift-log levels collapse onto LogLevel as documented
  Given a D3NexusLogHandler bound to a spy LogManager
  When a swift-log event at <SwiftLogLevel> is emitted
  Then the dispatched LogRecord level is <LogLevel>

  Examples:
    | SwiftLogLevel | LogLevel  |
    | trace         | .verbose  |
    | debug         | .debug    |
    | info          | .info     |
    | notice        | .info     |
    | warning       | .warning  |
    | error         | .error    |
    | critical      | .error    |
```

```gherkin
[Tier A - Unit]
Scenario: Existing trace identifiers in metadata are honoured rather than regenerated
  Given a swift-log event whose metadata carries traceId T and spanId S
  When the handler processes it
  Then the dispatched LogRecord reports traceId T and spanId S
```

```gherkin
[Tier A - Unit]
Scenario: An event without trace metadata receives freshly generated, well-formed identifiers
  Given a swift-log event with no trace metadata
  When the handler processes it
  Then traceId matches "^[0-9a-f]{32}$" and spanId matches "^[0-9a-f]{16}$"
```

```gherkin
[Tier A - Unit]
Scenario: The label becomes the record module and per-handler metadata is preserved
  Given a handler created with label "ThirdPartyLib" and metadata ["k": "v"]
  When an event is emitted
  Then the LogRecord module is "ThirdPartyLib"
  And its metadata contains "k" with value "v"
```

## Test & Verification Checklist

- [ ] **RED** — `SwiftLogBridgeTests` covering the full mapping table, metadata passthrough, both
      identifier paths, and label-to-module translation.
- [ ] **GREEN** — implement the handler and the bootstrap entry point.
- [ ] **REFACTOR** — `swiftformat`; `swiftlint --strict`; confirm the package still builds for the
      macOS host.
- [ ] **Verify** — `swift test --package-path Packages/D3NexusLogging` green;
      `swift build --package-path Packages/D3NexusLogging` resolves swift-log at the pinned version.

**TDD note**: `LoggingSystem.bootstrap` is process-global. Test the handler directly; do not call
bootstrap from a unit test.

## Definition of Done (DoD)

- swift-log pinned in `Package.swift`, and the package still builds for both `.iOS(.v16)` and
  `.macOS(.v13)`.
- The complete level-mapping table is covered by assertions and documented in the type's doc comment,
  including the lossy `critical` → `.error` collapse.
- Both identifier paths (honoured and generated) are covered.
- `Bridge/**` ≥ 85% line coverage.
- SwiftLint and SwiftFormat clean.

## Dependencies & Blockers

- Blocked by: [Task 2](task_2_log_manager_and_facade.md).
- Blocks: [Task 6](task_6_graph_wiring_and_core_adapter.md).

## References & Rollback

- `apple/swift-log` — <https://github.com/apple/swift-log>
- HLD deviation D1 — [pulse_logger.en.md](pulse_logger.en.md) §3
- Rollback: drop the dependency from `Package.swift` and delete `Bridge/`. The package returns to
  zero remote dependencies and every other task is unaffected.
