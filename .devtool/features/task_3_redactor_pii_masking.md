---
id: "task_3_redactor_pii_masking"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T04:47:44+07:00"
modified: "2026-09-19T04:47:44+07:00"
completedAt: null
labels: ["security", "logging", "pii", "fintech"]
order: "a3"
---

# Task 3: Redactor — Secret Masking & PII Patterns

Epic Reference: [pulse_logger](../epic/pulse_logger/pulse_logger.en.md) · BDD: [bdd_scenarios.md](../epic/pulse_logger/bdd_scenarios.md) UC-8

## Requirement Analysis

The source spec mandates redaction in §6 (Security & PII Redaction) but **assigned it to no task** —
it appeared only as an assertion inside a Network BDD scenario. This template is the base for a
fintech wallet, and Task 8 introduces Pulse's `URLSession` capture, which records **full request and
response bodies**. Redaction is therefore the single highest-risk component in this epic and gets a
task of its own.

Build a `Redactor` applied **once, at the `LogManagerImpl` boundary**, so every appender — present
and future, including a later Datadog or Sentry appender — inherits it without opting in. Task 8
applies the same component to the network capture path.

## Relevant Files & Context Pointers

- `Packages/D3NexusLogging/Sources/D3NexusLogging/Redaction/RedactionRule.swift` — create
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Redaction/Redactor.swift` — create
- `Packages/D3NexusLogging/Sources/D3NexusLogging/Manager/LogManagerImpl.swift` — **modify**: run
  every record through the redactor before dispatch
- `Packages/D3NexusLogging/Tests/D3NexusLoggingTests/RedactorTests.swift` — create
- Read for context: `Packages/Core/Sources/Core/Cache/SecureCacheStore.swift` (the repo's existing
  posture on secret handling)

## Design Rationale

- **Two rule kinds.** *Key-based* masking replaces the whole value of a sensitive metadata key
  (`Authorization`, `Cookie`, `X-API-Key`, `Session-Token`) with `[REDACTED]`; matching is
  case-insensitive, because HTTP header casing is not normalised by `URLRequest`. *Pattern-based*
  masking rewrites matches inside free-form message text (PAN, CVV, PIN, OTP).
- **Anchoring matters more than breadth.** An unanchored card-number regex will eat order
  references, timestamps and IDs, and a log that redacts everything is as useless as one that
  redacts nothing. Every pattern carries an explicit negative test — UC-8.2 pins the boundary with a
  four-digit order reference that must survive.
- **Applied at the manager, not at each appender.** Putting it in `LogManagerImpl.log(_:)` makes
  "a new appender leaks secrets" structurally impossible rather than a review item. UC-8.2's final
  scenario asserts exactly this with two spy appenders.
- **Rules are injected, not hard-coded (extraction constraint E3).** This package ships to other
  teams, and a shared SDK cannot assume every consumer is a fintech app. `Redactor` takes a
  `[RedactionRule]` from its caller and exposes a `.default` set — the four headers plus the
  PAN / CVV / PIN / OTP patterns this template needs. The default set carries the full 100% coverage
  obligation; the injection seam is what makes the component reusable rather than template-specific.
  `LogManagerImpl` uses `.default` unless the composition root overrides it (HLD §3.2).
- **Deterministic and pure.** `Redactor` is a value type with no I/O, so it is trivially testable to
  100% and safe to call from any isolation domain.
- **Compiled `NSRegularExpression` instances**, built once at construction — a per-record compile on
  a logging hot path is a real cost, and UC-8.3 puts a budget on it.

Applicable skills: `security-audit`, `code-health-audit`, `test-driven-development`.

## Impact Analysis & Blast Radius

- **Target symbols**: `RedactionRule`, `Redactor`, `LogManagerImpl.log(_:)`.
- **Downstream callers**: every appender, transitively — and from Task 8, the Pulse network capture.
- **Cross-platform bridges**: none.
- **Coverage threshold**: **100% line coverage on `Redaction/**`**. This is the security-audit tier
  of Gate 4; a partially covered redactor is a Gate 4 failure, not a warning.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

Authoritative copies in [bdd_scenarios.md](../epic/pulse_logger/bdd_scenarios.md). This task implements:

- **UC-8.1** — the four sensitive headers each masked to `[REDACTED]` with the raw value absent from
  the sanitised record; case-insensitive header matching.
- **UC-8.2** — card numbers masked in spaced, hyphenated and contiguous forms; a four-digit order
  reference **preserved**; redaction applied once at the manager boundary so neither spy appender
  ever observes a raw token.
- **UC-8.3** — a record with no sensitive content passes through byte-identical; a 256 KB message
  with 100 card-shaped substrings has all 100 masked within the documented budget.

## Test & Verification Checklist

- [ ] **RED** — write `RedactorTests` covering every scenario, including the negative
      (over-redaction) cases and the two-spy-appender containment test. Confirm each fails first.
- [ ] **GREEN** — implement `RedactionRule`, `Redactor`, and the `LogManagerImpl` call site.
- [ ] **REFACTOR** — hoist regex compilation out of the hot path; `swiftformat`;
      `swiftlint --strict`.
- [ ] **Verify** — `swift test --package-path Packages/D3NexusLogging` green; coverage report shows
      **100%** on `Redaction/**`; invoke the `security-audit` skill against the diff and resolve
      every finding before closing.

## Definition of Done (DoD)

- 100% line coverage on `Redaction/**`, evidenced by a coverage report, not asserted.
- Every sensitive header masked; every documented pattern masked; every negative case preserved.
- No raw secret reaches any appender — proven by the spy-appender scenario, not by inspection.
- The performance budget for a 256 KB payload is documented in the type's doc comment and met.
- `security-audit` skill reports zero blockers on this diff.
- SwiftLint and SwiftFormat clean.

## Dependencies & Blockers

- Blocked by: [Task 1](task_1_scaffold_logging_package.md).
- Blocks: [Task 4](task_4_oslog_appender.md). Consumed again by
  [Task 8](task_8_pulse_appender_and_session_capture.md).

## References & Rollback

- OWASP Mobile Top 10 (2024) — M6 Inadequate Privacy Controls
- HLD §3.1 — the unowned-item table that created this task
- Rollback: remove the `LogManagerImpl` call site and delete `Redaction/`. Records then flow
  unredacted, so this rollback is **not acceptable** once Task 8 has landed; revert Task 8 first.
