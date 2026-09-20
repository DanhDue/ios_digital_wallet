---
id: "task_8_pulse_appender_and_session_capture"
status: "done"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T04:47:44+07:00"
modified: "2026-09-19T12:57:03Z"
completedAt: "2026-09-19T12:57:03Z"
labels: ["pulse", "telemetry", "network", "security"]
order: "a8"
---

# Task 8: Pulse Appender & Instrumented `URLSession` Capture

Epic Reference: [pulse_logger](../epic/pulse_logger/pulse_logger.en.md) · BDD: [bdd_scenarios.md](../epic/pulse_logger/bdd_scenarios.md) UC-9

## Requirement Analysis

Bring `kean/Pulse` into the project — **at the composition root only** — and deliver the two things
it is actually here for: structured log ingestion into `Pulse.LoggerStore`, and rich network capture
(duration, status, headers, request and response bodies, cURL export).

Two Stage-2 findings shape this task:

1. **Pulse does not belong inside `Packages/D3NexusLogging`.** Every existing local package uses path
   dependencies only, and CI runs `for dir in Packages/* Features/*; do swift test --package-path
   "$dir"` on a macOS host — a remote Pulse dependency would have to resolve for the package and for
   every downstream consumer on every standalone build. Keeping Pulse in `App/`, where it is already
   an external via Tuist, keeps the package offline-testable and keeps appenders pluggable, which is
   what Non-Goal 3 promises for a future Datadog or Sentry sink (HLD D5).
2. **The network data Pulse is wanted for cannot come from the interceptor chain.**
   `RequestInterceptor.didReceive` is synchronous, body-less and timing-free (HLD D3). Pulse captures
   at the `URLSession` layer through `URLSessionProxyDelegate`. `NetworkComposition.makeAPIClient`
   already accepts an injectable `session: URLSession`, so the composition root can hand it an
   instrumented session **without `Packages/Network` changing at all**.

## Relevant Files & Context Pointers

- `Tuist/Package.swift` — modify: add `kean/Pulse` to the marker region **and** the `lean` array
- `Project.swift` — modify: add the Pulse product to the `enterprise` **and** `lean` app target
- `App/Sources/Composition/PulseAppender.swift` — create (`#if DEBUG`)
- `App/Sources/Composition/PulseSessionFactory.swift` — create: builds the instrumented `URLSession`
- `App/Sources/Composition/LoggingComposition.swift` — modify: register `PulseAppender`
- `App/Sources/Composition/AppComposition.swift` — modify: pass the instrumented session into
  `NetworkComposition.makeAPIClient(session:)`
- `App/Tests/AppTests/PulseCaptureTests.swift` — create
- **Unchanged by design**: everything under `Packages/Network/Sources` and
  `Packages/D3NexusLogging/Sources`
- Read first: `App/Sources/Composition/NetworkComposition.swift` (the existing `session:` parameter
  and the `URLProtocol` stubbing convention in `Packages/Network/Tests/NetworkTests/URLProtocolStub.swift`)

## Design Rationale

- **`PulseAppender` sets `respectsModuleToggle = true`** — it is the developer-facing sink, so muting
  a noisy module must clean up the in-app console while `OSLogAppender` keeps system telemetry intact.
- **Redaction is not optional on this path.** Pulse persists full bodies. Task 3's `Redactor` must be
  applied to captured headers and bodies before they reach the store, not after. UC-9.2 is the
  acceptance criterion and it is a security-tier scenario.
- **Version pinning is an explicit step, not an assumption.** The HLD deliberately does not state a
  Pulse version: this task must resolve the package, record the exact version in `Tuist/Package.swift`,
  and **verify the resolved release supports both `.iOS(.v16)` and the macOS host** used by the CI
  package loop. If it does not, stop and report rather than lowering a platform floor —
  `Module.iOSDeploymentTarget` is the single source of truth and is not to be changed by this epic.
- **`#if DEBUG` around the appender, not around the session factory.** Whether network capture ships
  in Release is a separate decision from whether the console does; keep the two switches independent
  and document which is which.
- **Rollback is two files.** Deleting the appender and the session factory returns the app to
  `OSLogAppender` plus a plain `URLSession`. UC-9.3's final scenario asserts this path really works.

Applicable skills: `security-audit`, `architecture-audit`, `ios-ui-audit`.

## Impact Analysis & Blast Radius

- **Target symbols**: `PulseAppender`, `PulseSessionFactory`, `LoggingComposition`,
  `AppComposition.makeNetworkStack`.
- **Downstream callers**: the app's `URLSessionAPIClient` instances — both the authed client and
  `makeBareAPIClient`. Decide and document whether the bare refresh client is also instrumented;
  capturing refresh traffic means capturing tokens, which raises the redaction stakes.
- **New external dependency**: `kean/Pulse`, in the app target only.
- **Cross-platform bridges**: none.
- **Coverage threshold**: appender mapping and the redaction call path ≥ 85%; the redaction assertions
  themselves are security-tier and must be exhaustive.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

Authoritative copies in [bdd_scenarios.md](../epic/pulse_logger/bdd_scenarios.md). This task implements:

- **UC-9.1** — a stubbed 200 response yields a captured entry carrying duration, response byte count,
  an inspectable decoded JSON body, and an exportable cURL representation.
- **UC-9.2** — a request carrying `Authorization: Bearer …` and a response body containing a card
  number produce a stored entry showing `[REDACTED]` for the header and a masked body, with the raw
  token never reaching the store.
- **UC-9.3** — a connection timeout is recorded as an entry while the error still surfaces to the
  caller unchanged; and composing with a plain `URLSession` leaves the request flow fully functional.
- **UC-4.1** — the `"pulse"` half of the dispatch truth table, now against the real appender.

## Test & Verification Checklist

- [ ] **RED** — `PulseCaptureTests` driven through the existing `URLProtocolStub` so no real network
      is touched. Write the redaction assertions first; they are the reason this task exists.
- [ ] **GREEN** — implement the appender and session factory; register both in `LoggingComposition`
      and `AppComposition`.
- [ ] **REFACTOR** — `swiftformat`; `swiftlint --strict`; confirm `#if DEBUG` boundaries compile in
      both configurations (`xcodebuild -configuration Release` must still build).
- [ ] **Tier B** — `swift test --package-path ArchTests`; confirm
      `swift test --package-path Packages/D3NexusLogging` **still resolves without Pulse**, which is
      the proof that D5 held.
- [ ] **Tier C** — `tuist generate --no-open` then `xcodebuild test` on the simulator; repeat for
      `lean` mode.
- [ ] **Security** — run the `security-audit` skill against the diff; zero blockers required.

## Definition of Done (DoD)

- Pulse resolved, version pinned in `Tuist/Package.swift`, and its platform support verified against
  `.iOS(.v16)` and the CI macOS host — with the resolved version recorded in the commit body.
- `Packages/D3NexusLogging` still builds and tests **offline, with no Pulse dependency**.
- `Packages/Network/Sources` unchanged by this task.
- Captured entries carry duration, byte count, body and cURL export.
- No raw credential or card number reaches the Pulse store, asserted rather than reviewed.
- Release configuration builds with the debug-only code compiled out.
- Both `enterprise` and `lean` generate and build.
- `security-audit` reports zero blockers.

## Dependencies & Blockers

- Blocked by: [Task 6](task_6_graph_wiring_and_core_adapter.md),
  [Task 7](task_7_trace_context_seam_and_interceptor.md).
- Blocks: [Task 9](task_9_pulse_ui_and_settings.md).

## References & Rollback

- Pulse — <https://github.com/kean/Pulse>
- `URLSessionProxyDelegate` — Pulse network logging documentation
- HLD deviations D3, D5 — [pulse_logger.en.md](../epic/pulse_logger/pulse_logger.en.md) §3
- Rollback: delete `PulseAppender.swift` and `PulseSessionFactory.swift`, drop the Pulse dependency
  from both manifests. `OSLogAppender` and the plain `URLSession` carry on — verified by UC-9.3.
