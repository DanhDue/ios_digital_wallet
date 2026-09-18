---
id: "task_7_trace_context_seam_and_interceptor"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T04:47:44+07:00"
modified: "2026-09-19T04:47:44+07:00"
completedAt: null
labels: ["architecture", "network", "w3c", "interceptor"]
order: "a7"
---

# Task 7: `Core.TraceContextProviding` Seam & Network `TraceContextInterceptor`

Epic Reference: [pulse_logger](../epic/pulse_logger/pulse_logger.en.md) · BDD: [bdd_scenarios.md](../epic/pulse_logger/bdd_scenarios.md) UC-3

## Requirement Analysis

Inject the W3C `traceparent` header on outgoing requests **without giving `Packages/Network` a
dependency on the logging package**.

The source spec had `Network` import `Logging` directly. That is a Layer 3 → Layer 3 edge, and
`docs/architecture/ARCHITECTURE.md` §3 states Layer 3 is "sibling modules, **no intra-layer edge**"
with the whole graph "a one-way DAG"; `Packages/Network/Package.swift` documents "Depends on `Core`
**only**". Taking that route would have required amending the architecture doc, the manifest comment,
`CLAUDE.md` and the governance rules (HLD D4).

Instead, mirror the precedent this repo already set for the 401 path: `Network` surfaces logout
through `Core.AuthEventSink` and the composition root binds it. Add a equally small
`Core.TraceContextProviding`, have the interceptor depend on that, and bind it in `App`.

The spec's interceptor code also targets an API that does not exist. The real protocol is
`RequestInterceptor` with `adapt(_:) async -> URLRequest`, `didReceive(_ response: HTTPURLResponse)`
and `retry(_:dueTo:)`. **`didReceive` is synchronous, receives no `Data` and carries no timing** — so
response duration, byte count and body inspection are structurally impossible here and belong to
Task 8 (HLD D3).

## Relevant Files & Context Pointers

- `Packages/Core/Sources/Core/Logging/TraceContextProviding.swift` — create
- `Packages/Network/Sources/Network/Interceptor/TraceContextInterceptor.swift` — create
- `Packages/Network/Sources/Network/Interceptor/LoggingInterceptor.swift` — leave as is; it keeps
  logging status through `Core.Logger`, which now resolves to the adapter from Task 6
- `App/Sources/Composition/D3NexusTraceContextProvider.swift` — create
- `App/Sources/Composition/NetworkComposition.swift` — modify: add the interceptor to the chain
- `Packages/Network/Tests/NetworkTests/TraceContextInterceptorTests.swift` — create
- Read first: `Packages/Network/Sources/Network/Interceptor/RequestInterceptor.swift` (the real
  signatures), `App/Sources/Composition/NetworkComposition.swift` (the `BusAuthEventSink` precedent
  this task copies)

## Design Rationale

- **The seam stays minimal.** `TraceContextProviding` exposes one method returning an optional
  `traceparent` string. `Core` gains no knowledge of spans, loggers or W3C beyond that string, so
  the zero-dependency floor (K7) is untouched.
- **Returning `String?`, not `String`.** A nil result means "no trace context available" and the
  interceptor leaves the request alone. A non-optional API would force a fabricated header when
  logging is uninitialised — worse than no header, because a malformed `traceparent` can confuse a
  downstream APM.
- **A separate interceptor, not a change to `LoggingInterceptor`.** `LoggingInterceptor` has existing
  tests and a single responsibility. Header injection is a different concern with a different
  dependency, and `URLSessionAPIClient` already composes an interceptor array — adding one entry is
  cheaper and more reversible than widening an existing type.
- **Idempotency.** If an upstream caller already set `traceparent`, do not overwrite or duplicate it.
  This matters the moment the app participates in a trace started elsewhere.
- **Where the span comes from.** `D3NexusTraceContextProvider` in `App` calls `withSpan()` per
  request and formats `00-{traceId}-{spanId}-01`. Because Task 2's child loggers hold only value-type
  identifiers, the per-request span creates no retain cycle with the interceptor's async context.

Applicable skills: `security-audit`, `architecture-audit`, `test-driven-development`.

## Impact Analysis & Blast Radius

- **Target symbols**: `Core.TraceContextProviding`, `TraceContextInterceptor`,
  `D3NexusTraceContextProvider`, `NetworkComposition.makeAPIClient`.
- **Downstream callers**: `URLSessionAPIClient`'s interceptor chain; every outgoing request gains one
  header.
- **Cross-platform bridges**: backend APM systems consuming `traceparent`. The header format is a
  published contract — a malformed value is a silent integration failure, which is why UC-3.1 pins it
  with a regex.
- **Coverage threshold**: `TraceContextInterceptor` ≥ 90% line; `TraceContextProviding` conformance in
  `App` ≥ 85%.
- **Governance**: `Packages/Network/Package.swift` must still declare `Core` and nothing else.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

Authoritative copies in [bdd_scenarios.md](../epic/pulse_logger/bdd_scenarios.md). This task implements:

- **UC-3.1** — `adapt(_:)` adds a `traceparent` matching `^00-[0-9a-f]{32}-[0-9a-f]{16}-01$`, with no
  other header of the original request modified.
- **UC-3.2** — a request already carrying `traceparent` ends with exactly one; a nil trace context
  leaves the request header-free and still dispatchable.
- **UC-3.3** — `Packages/Network/Package.swift` declares `Core` and nothing else, and no file under
  `Packages/Network/Sources` imports `D3NexusLogging`.
- **UC-3.4** — `didReceive(_:)` emits an error-level record naming status 500, reads no body, and
  returns without throwing.

## Test & Verification Checklist

- [ ] **RED** — `TraceContextInterceptorTests` written against the **real** `RequestInterceptor`
      signatures. Confirm each fails first.
- [ ] **GREEN** — implement the `Core` seam, the interceptor, and the `App` provider; add the
      interceptor to `NetworkComposition`'s chain.
- [ ] **REFACTOR** — `swiftformat`; `swiftlint --strict`; confirm interceptor ordering relative to
      `RefreshingAuthInterceptor` is intentional and documented.
- [ ] **Tier B** — `swift test --package-path ArchTests`;
      `bash scripts/check_module_boundaries.sh`; confirm the Network manifest is unchanged apart from
      nothing at all.
- [ ] **Verify** — `swift test --package-path Packages/Network` and
      `swift test --package-path Packages/Core` both green.

## Definition of Done (DoD)

- `traceparent` present and regex-valid on outgoing requests.
- **`Packages/Network/Package.swift` still declares `Core` only** — this is the load-bearing
  acceptance criterion of the task.
- No file under `Packages/Network/Sources` imports `D3NexusLogging`.
- Idempotent injection; nil context handled without a malformed header.
- Existing `LoggingInterceptorTests` still pass unmodified.
- `ArchTests` and `check_module_boundaries.sh` clean.
- `TraceContextInterceptor` ≥ 90% line coverage.

## Dependencies & Blockers

- Blocked by: [Task 6](task_6_graph_wiring_and_core_adapter.md).
- Blocks: [Task 8](task_8_pulse_appender_and_session_capture.md).

## References & Rollback

- W3C Trace Context `traceparent` — <https://www.w3.org/TR/trace-context/#traceparent-header>
- The precedent this task copies: `Core.AuthEventSink` / `BusAuthEventSink`, Source Spec Changelog #8
- HLD deviations D3, D4 — [pulse_logger.en.md](../epic/pulse_logger/pulse_logger.en.md) §3
- Rollback: remove the interceptor from `NetworkComposition`'s array. Requests go out without the
  header; nothing else changes.
