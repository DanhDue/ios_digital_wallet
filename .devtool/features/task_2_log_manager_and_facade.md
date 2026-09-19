---
id: "task_2_log_manager_and_facade"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T03:32:30+07:00"
modified: "2026-09-19T04:47:44+07:00"
completedAt: null
labels: ["architecture", "logging", "concurrency", "memory-safety"]
order: "a2"
---

# Task 2: LogManager Dispatch Engine, LoggerProtocol & Facade

Epic Reference: [pulse_logger](../epic/pulse_logger/pulse_logger.en.md) · BDD: [bdd_scenarios.md](../epic/pulse_logger/bdd_scenarios.md) UC-1, UC-2, UC-4

## Requirement Analysis

Implement the dispatch core: the `LogAppender` / `LogManager` contracts, a thread-safe
`LogManagerImpl` enforcing the module × appender toggle matrix, `LoggerProtocol` with leak-free
`withSpan()`, and the `D3NexusLogger` facade. Toggle state persists to `UserDefaults` under
`logging.module_toggles` and `logging.appender_toggles`.

Two corrections from the source spec apply here:

1. Methods are **`debug` / `info` / `warning` / `error` / `verbose`**, not `d` / `i` / `w` / `e` / `v`.
   `quality/.swiftlint.yml` excludes only `[id, to, x, y, t]` from `identifier_name`, CI runs
   `swiftlint --strict`, and the repo already resolved this exact conflict once — see the doc comment
   in `Packages/Core/Sources/Core/Logging/Logger.swift`. The full names also make Task 6's
   `Core.Logger` adapter a 1:1 mapping (HLD D2).
2. `D3NexusLogger.getLogger` returns a **`NoOpLogger`** when uninitialised instead of calling
   `fatalError`. The spec put that `fatalError` behind a default argument, which is evaluated at
   every call site — a change in composition order would crash production (HLD D8).

## Relevant Files & Context Pointers

- `Packages/D3NexusLogging/Sources/D3NexusLogging/Appender/LogAppender.swift` — create
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Manager/{LogManager,LogManagerImpl,ToggleStore}.swift` — create
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Logger/{LoggerProtocol,LoggerImpl,NoOpLogger}.swift` — create
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Facade/D3NexusLogger.swift` — create
- `Packages/D3NexusLogging/Tests/D3NexusLoggingTests/{DispatchMatrixTests,SpanTests,ToggleStoreTests,FacadeTests}.swift` — create
- Read for conventions: `Packages/Core/Sources/Core/Logging/Logger.swift`,
  `Packages/Network/Sources/Network/Interceptor/RefreshCoordinator.swift` (existing concurrency style)

## Design Rationale

- **`LogAppender`**: `Sendable`, exposing `id`, `respectsModuleToggle`, `append(_:)`. The
  `respectsModuleToggle` flag is what lets a developer mute a noisy module in the in-app console
  without blinding system telemetry — `OSLogAppender` sets it `false`, debug appenders `true`.
- **`LogManagerImpl` concurrency**: the source spec declared `LogManager: Sendable` while giving it
  mutating operations (`registerAppender`, `setModuleEnabled`), and guarded the facade with
  `NSLock` on every `getLogger`. Under Swift 6 that combination needs stating explicitly. Use
  `OSAllocatedUnfairLock` (available at the iOS 16 floor) around a single state struct holding
  appenders and both toggle maps, and document the isolation contract in the type's doc comment.
  `getLogger` must not contend on the hot path — resolve toggles at `log(_:)` time, not at logger
  construction.
- **`withSpan()`**: returns a new `LoggerImpl` carrying the parent's `traceId`, a fresh `spanId`,
  and `parentSpanId` **as a `String` value**. It holds no reference to the parent, so a parent can
  deallocate while its children are still live (HLD Goal 7). Task 1's `CyclicLoggerPair` fixture is
  the counter-example this must be tested against: same shape, strong parent reference, asserted to
  leak. An `EscapingClosureLogger` fixture is added here for the other realistic shape — an escaping
  closure capturing `self` strongly — since `withSpan()` is most often called inside one.
- **Dispatch order**: appender kill-switch is checked before the module toggle — a disabled appender
  receives nothing regardless of module state. This is the truth table in UC-4.1 and it is the
  single most test-worthy branch in the package.
- **`ToggleStore`**: injectable `UserDefaults` suite so tests never touch `.standard`. Unknown
  modules default to enabled; malformed persisted data falls back to defaults rather than trapping.

Applicable skills: `architecture-audit`, `code-health-audit`, `test-driven-development`.

## Impact Analysis & Blast Radius

- **Target symbols**: `LogAppender`, `LogManager`, `LogManagerImpl`, `ToggleStore`, `LoggerProtocol`,
  `LoggerImpl`, `NoOpLogger`, `D3NexusLogger`.
- **Downstream callers**: none in the app yet; Tasks 4, 5, 6, 7, 8 all build on these contracts, so
  **this task freezes the public API** for the rest of the epic (parallel-execution Rule 1).
- **Cross-platform bridges**: none.
- **Coverage thresholds**: `Manager/**` and `Logger/**` ≥ 90% line; the 8-row dispatch matrix must be
  covered exhaustively, not representatively.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

Authoritative copies in [bdd_scenarios.md](../epic/pulse_logger/bdd_scenarios.md). This task implements:

- **UC-1.1** — structured record with hex-valid identifiers; all five severities mapping to the
  correct `LogLevel`.
- **UC-1.3** — a failing appender does not starve the appenders registered after it.
- **UC-2.1 / 2.2** — child preserves `traceId`, gets a distinct `spanId`, links `parentSpanId`;
  three-level lineage.
- **UC-2.3** — releasing the parent deallocates it immediately while the child keeps working.
- **UC-2.4** — 500 concurrent `withSpan()` calls produce 500 distinct span identifiers.
- **UC-4.1** — the full 8-row dispatch truth table.
- **UC-4.2** — toggles survive a store rebuild; unknown module defaults to enabled; corrupted
  persisted data falls back to defaults without crashing.
- **UC-4.3** — 100 concurrent logs while another task flips the module toggle: no race, no
  corruption, deterministic final persisted value.
- **Cross-cutting** — `getLogger` before initialisation returns `NoOpLogger` and does not terminate
  the process.

## Test & Verification Checklist

- [ ] **RED** — write `DispatchMatrixTests` (all 8 rows as a parameterised suite), `SpanTests`,
      `ToggleStoreTests`, `FacadeTests`. Confirm failures are for the right reason.
- [ ] **GREEN** — minimal `LogManagerImpl`, `LoggerImpl`, `NoOpLogger`, `ToggleStore`, facade.
- [ ] **REFACTOR** — run the concurrency tests under Thread Sanitizer
      (`swift test --package-path Packages/D3NexusLogging --sanitize=thread`); `swiftformat`;
      `swiftlint --strict`.
- [ ] **Verify** — `swift test --package-path Packages/D3NexusLogging` green, including
      `trackForMemoryLeaks` on `LogManagerImpl`, `LoggerImpl` and every child span created in tests.

## Definition of Done (DoD)

- All 8 dispatch-matrix rows pass as distinct assertions.
- Thread Sanitizer reports zero data races on the concurrency scenarios.
- No child logger keeps a parent alive; `trackForMemoryLeaks` green on every allocated instance.
- `getLogger` before `initialize` returns a no-op and does not trap in a Release-like configuration.
- `Manager/**` and `Logger/**` ≥ 90% line coverage.
- Public API frozen and documented — later tasks may add appenders, never change these signatures.
- SwiftLint and SwiftFormat clean.

## Dependencies & Blockers

- Blocked by: [Task 1](task_1_scaffold_logging_package.md).
- Blocks: [Task 4](task_4_oslog_appender.md), [Task 5](task_5_swift_log_bridge.md).

## References & Rollback

- HLD deviations D2, D8 — [pulse_logger.en.md](../epic/pulse_logger/pulse_logger.en.md) §3
- `OSAllocatedUnfairLock` — <https://developer.apple.com/documentation/os/osallocatedunfairlock>
- Rollback: revert this task's files; Task 1's foundation stands alone and still compiles.
