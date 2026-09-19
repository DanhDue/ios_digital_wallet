---
id: "task_1_scaffold_logging_package"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T03:32:30+07:00"
modified: "2026-09-19T04:47:44+07:00"
completedAt: null
labels: ["architecture", "logging", "package", "memory-safety"]
order: "a1"
---

# Task 1: Package Scaffolding, Data Models & Cycle-Safe Trace Tree

Epic: [pulse_logger](pulse_logger.en.md) · BDD: [bdd_scenarios.md](bdd_scenarios.md) UC-1, UC-6

## Requirement Analysis

Create the local SPM package `Packages/AppLogging` and its pure foundation: log levels, the
immutable `LogRecord`, W3C-correct identifier generation, and a trace-tree builder that cannot
recurse forever or leak. **Zero remote dependencies at this task** — swift-log arrives in Task 5,
Pulse never enters this package at all (HLD D5).

The package name is `AppLogging` — not `Logging`, and not `Logger`. `apple/swift-log` ships its
module as `Logging`, so a local target of that name is a SwiftPM duplicate-module error and makes
every consumer's `import Logging` ambiguous. `Logger` is unavailable for a different reason:
`Core` already declares `public protocol Logger` and 19 call sites reference it unqualified,
including the Mason brick. `AppLogging` mirrors the existing `AppUIKit` convention and collides with
neither (HLD D1, D1.1).

## Relevant Files & Context Pointers

- `Packages/AppLogging/Package.swift` — **create**
- `Packages/AppLogging/Sources/AppLogging/Model/LogLevel.swift` — create
- `Packages/AppLogging/Sources/AppLogging/Model/LogRecord.swift` — create
- `Packages/AppLogging/Sources/AppLogging/Trace/TraceIdentifier.swift` — create
- `Packages/AppLogging/Sources/AppLogging/Trace/TraceNode.swift` — create
- `Packages/AppLogging/Sources/AppLogging/Trace/TraceTree.swift` — create
- `Packages/AppLogging/Tests/AppLoggingTests/TestSupport/MemoryLeakTestSupport.swift` — create
- `Packages/AppLogging/Tests/AppLoggingTests/{LogRecordTests,TraceIdentifierTests,TraceTreeTests}.swift` — create
- Read for conventions: `Packages/Core/Package.swift` (manifest style, the `.macOS(.v13)` host-test
  rationale), `Packages/Network/Tests/NetworkTests/TestSupport.swift`

## Design Rationale

- **Manifest**: `platforms: [.iOS(.v16), .macOS(.v13)]`. The macOS floor is **not optional** — CI
  runs `for dir in Packages/* Features/*; do swift test --package-path "$dir"` on a macOS host
  (`.github/workflows/ci.yml`), so the package must build for the host toolchain exactly as `Core`
  and `Network` already do.
- **`LogLevel`**: `Int`-backed enum, `Comparable` / `Sendable` / `Codable`, ordered
  `verbose < debug < info < warning < error`.
- **`LogRecord`**: immutable `struct`, `Sendable` / `Equatable` / `Codable`, carrying `module`,
  `level`, `message`, `timestamp`, `traceId`, `spanId`, `parentSpanId`, `errorDescription`,
  `metadata`.
- **`TraceIdentifier`**: generates a 32-hex `traceId` and a 16-hex `spanId` from random bytes —
  `String(format: "%016llx", UInt64.random(in: .min ... .max))` and the 128-bit equivalent. The
  spec's `String(UUID().uuidString.prefix(16))` is **wrong**: `uuidString` embeds `-` at index 8
  and 13, so the value fails the spec's own `^[0-9a-f]{16}$` regex (HLD D6).
- **`TraceNode` as a value type**: the spec modelled it as a `final class` with `var children`
  marked `@unchecked Sendable`. Two records that reference each other's spans would then build a
  cycle — infinite traversal *and* a permanent leak, contradicting Goal 7 of this epic. A `struct`
  built bottom-up removes the whole failure class by construction (HLD D7).
- **`buildTraceTree`** stays a pure, side-effect-free function: parent resolution by `spanId`, a
  visited set for cycle detection, a depth cap for pathological chains, orphans promoted to roots,
  and a guarantee that the node count out equals the record count in.

Applicable skills: `code-health-audit`, `architecture-audit`, `test-driven-development`.

## Impact Analysis & Blast Radius

- **Target symbols**: `LogLevel`, `LogRecord`, `TraceIdentifier`, `TraceNode`, `buildTraceTree`,
  `trackForMemoryLeaks`.
- **Downstream callers**: none yet — this task adds a package nothing imports. Blast radius is
  intentionally zero, which is why it is first.
- **Cross-platform bridges**: none.
- **Coverage thresholds**: `Trace/**` **100%** line (identifier format and the cycle guard are the
  two places a silent defect would survive to production); `Model/**` ≥ 90%.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

Authoritative copies live in [bdd_scenarios.md](bdd_scenarios.md). This task implements:

- **UC-1.2** — empty message/metadata; 64 KB message; `Error` captured as `errorDescription`;
  10000 generated spanIds all matching `^[0-9a-f]{16}$` and all distinct.
- **UC-6.1** — three-level tree from ordered records.
- **UC-6.2** — out-of-order input yielding an identical tree; orphan promoted to root with zero
  records dropped; empty input; five records sharing one `spanId` all retained.
- **UC-6.3** — **the cycle guard**: a two-record cycle terminates within the test timeout with each
  record appearing exactly once and no node reachable from itself; a self-parented record becomes a
  childless root; a 10000-deep chain completes without stack overflow.
- **UC-7.1** (partial) — a nested `TraceNode` structure leaves nothing retained at teardown.

## Test & Verification Checklist

- [ ] **RED** — write `LogRecordTests`, `TraceIdentifierTests`, `TraceTreeTests` covering every
      scenario above. Confirm each fails for the right reason. The cycle test must be written
      **before** the algorithm, and must be shown to hang or crash against the source spec's
      class-based implementation.
- [ ] **GREEN** — minimal implementation of `LogLevel`, `LogRecord`, `TraceIdentifier`, `TraceNode`,
      `TraceTree`, `MemoryLeakTestSupport`.
- [ ] **REFACTOR** — full `Sendable` conformance with no `@unchecked` anywhere in this task;
      `swiftformat --config quality/.swiftformat .`;
      `swiftlint lint --strict --config quality/.swiftlint.yml`.
- [ ] **Verify** — `swift test --package-path Packages/AppLogging` passes;
      `swift build --package-path Packages/AppLogging` succeeds standalone and offline.

**TDD note**: the deep-chain and cycle tests are the point of this task. A green suite without them
does not satisfy the DoD.

## Definition of Done (DoD)

- `Packages/AppLogging` builds under Swift 6 with zero warnings and **zero remote dependencies**.
- Every listed BDD scenario passes.
- `Trace/**` reaches 100% line coverage; `Model/**` ≥ 90%.
- No `@unchecked Sendable` in this task's code.
- `trackForMemoryLeaks` available to every later task.
- SwiftLint and SwiftFormat clean; `git status` clean apart from the intended files.

## Dependencies & Blockers

- Blocked by: none.
- Blocks: [Task 2](task_2_log_manager_and_facade.md), [Task 3](task_3_redactor_pii_masking.md).

## References & Rollback

- W3C Trace Context — <https://www.w3.org/TR/trace-context/>
- HLD deviations D1, D6, D7 — [pulse_logger.en.md](pulse_logger.en.md) §3
- Rollback: delete `Packages/AppLogging/`. Nothing else references it yet.
