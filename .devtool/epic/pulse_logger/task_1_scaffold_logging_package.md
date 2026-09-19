---
id: "task_1_scaffold_logging_package"
status: "done"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T03:32:30+07:00"
modified: "2026-09-19T12:01:50Z"
completedAt: "2026-09-19T12:01:50Z"
labels: ["architecture", "logging", "package", "memory-safety"]
order: "a1"
---

# Task 1: Package Scaffolding, Data Models & Cycle-Safe Trace Tree

Epic: [pulse_logger](pulse_logger.en.md) · BDD: [bdd_scenarios.md](bdd_scenarios.md) UC-1, UC-6

## Requirement Analysis

Create the local SPM package `Packages/D3NexusLogging` and its pure foundation: log levels, the
immutable `LogRecord`, W3C-correct identifier generation, and a trace-tree builder that cannot
recurse forever or leak. **Zero remote dependencies at this task** — swift-log arrives in Task 5,
Pulse never enters this package at all (HLD D5).

The package name is `D3NexusLogging` — not `Logging`, not `Logger`, not `AppLogging`.
`apple/swift-log` ships its module as `Logging`, so a local target of that name is a SwiftPM
duplicate-module error. `Logger` is unavailable for a different reason: `Core` already declares
`public protocol Logger` and 19 call sites reference it unqualified, including the Mason brick.
`AppLogging` would fit this repo's conventions but is wrong for a package intended to ship to other
teams — "App" names nothing once it leaves this app (HLD D1, D1.1).

**Extraction constraint E1 applies from this task onward:** the package **must not depend on
`Packages/Core`**, nor on any other package in this repository. Nothing in the file list below needs
it. `Package.swift` declares **no dependencies at all** at this task, and only `apple/swift-log` from
Task 5. If a later task finds itself reaching for `Core`, that is a design error — the abstraction
belongs in the package or the glue belongs in `App/` (HLD §3.2).

## Relevant Files & Context Pointers

- `Packages/D3NexusLogging/Package.swift` — **create**
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Model/LogLevel.swift` — create
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Model/LogRecord.swift` — create
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Trace/TraceIdentifier.swift` — create
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Trace/TraceNode.swift` — create
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Trace/TraceTree.swift` — create
- `Packages/D3NexusLogging/Tests/D3NexusLoggingTests/TestSupport/MemoryLeakTestSupport.swift` — create
- `Packages/D3NexusLogging/Tests/D3NexusLoggingTests/LeakFixtures/LeakFixtures.swift` — create
  (**`Tests/` only — a deliberately leaking type must never ship in the extracted SDK, E1**)
- `Packages/D3NexusLogging/Tests/D3NexusLoggingTests/LeakDetectorMetaTests.swift` — create
- `Packages/D3NexusLogging/Tests/D3NexusLoggingTests/TeardownTests.swift` — create
- `Packages/D3NexusLogging/Tests/D3NexusLoggingTests/{LogRecordTests,TraceIdentifierTests,TraceTreeTests}.swift` — create
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
- **The leak detector is itself proven to fire.** This repo already requires it of its other guards:
  *"Each rule was proven to fire before being trusted"* (`docs/architecture/ARCHITECTURE.md` §VI.1,
  on ArchTests K7). `LeakFixtures` supplies deliberately leaking shapes that mirror this module's
  real risks — `CyclicLoggerPair` (child holding its parent, the thing `withSpan()` must never do),
  `RetainingAppender` (appender ↔ manager cycle), and `ClassBasedTraceNode` (the source spec's D7
  implementation, kept as evidence). Each fixture is tested **as a discriminating pair**: the leaking
  shape asserts `XCTAssertNotNil` on a weak reference, the real type asserts `XCTAssertNil`. A suite
  where only the second half exists proves nothing, because a detector that never fires passes it.
- **No `XCTExpectFailure`.** It appears nowhere in this repo and it fights teardown ordering. The
  meta-test instead gives `trackForMemoryLeaks` an injectable failure handler (defaulting to
  `XCTFail`) and asserts a spy handler was invoked. Small seam, deterministic result.
- **A `TeardownTests.swift` alongside the fixtures**, matching the convention already present in
  `Packages/Network`, `Packages/Framework`, `Packages/Shell` and `Features/Settings`: a scoped
  closure, `weak var`, `XCTAssertNil`. `trackForMemoryLeaks` is the low-ceremony complement to that
  convention, **not** a replacement — do not invent a third idiom.

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
      scenario above. Confirm each fails for the right reason.
- [ ] **RED (detector)** — write `LeakDetectorMetaTests` and the `LeakFixtures` pairs. The leaking
      fixture must assert `XCTAssertNotNil`; the real type must assert `XCTAssertNil`.
- [ ] **Cycle demonstration** — the class-based D7 implementation is used **once, manually**, to
      watch the cycle test not terminate. That demonstration is **never committed**: a test that
      hangs is a bad CI artifact because it blocks the run until timeout. The committed test asserts
      *bounded termination* — the call returns within an explicit deadline — not the absence of a
      hang.
- [ ] **GREEN** — minimal implementation of `LogLevel`, `LogRecord`, `TraceIdentifier`, `TraceNode`,
      `TraceTree`, `MemoryLeakTestSupport`.
- [ ] **REFACTOR** — full `Sendable` conformance with no `@unchecked` anywhere in this task;
      `swiftformat --config quality/.swiftformat .`;
      `swiftlint lint --strict --config quality/.swiftlint.yml`.
- [ ] **Verify** — `swift test --package-path Packages/D3NexusLogging` passes;
      `swift build --package-path Packages/D3NexusLogging` succeeds standalone and offline.

**TDD note**: the deep-chain and cycle tests are the point of this task. A green suite without them
does not satisfy the DoD.

## Definition of Done (DoD)

- `Packages/D3NexusLogging` builds under Swift 6 with zero warnings, **zero remote dependencies**,
  and **no dependency on any package in this repository** (extraction constraint E1).
- Every listed BDD scenario passes.
- `Trace/**` reaches 100% line coverage; `Model/**` ≥ 90%.
- No `@unchecked Sendable` in this task's code.
- `trackForMemoryLeaks` available to every later task, **with its own failure path proven** by the
  meta-test rather than assumed.
- Every leak fixture is verified to actually leak; every real type is verified not to. Both halves
  of each pair are present.
- `TeardownTests.swift` exists and follows the convention of the four sibling packages.
- No committed test hangs; the cycle test asserts bounded termination.
- SwiftLint and SwiftFormat clean; `git status` clean apart from the intended files.

## Dependencies & Blockers

- Blocked by: none.
- Blocks: [Task 2](task_2_log_manager_and_facade.md), [Task 3](task_3_redactor_pii_masking.md).

## References & Rollback

- W3C Trace Context — <https://www.w3.org/TR/trace-context/>
- HLD deviations D1, D6, D7 — [pulse_logger.en.md](pulse_logger.en.md) §3
- Rollback: delete `Packages/D3NexusLogging/`. Nothing else references it yet.
