---
id: "task_5_network_trace_interceptor"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T03:32:30+07:00"
modified: "2026-09-19T03:32:30+07:00"
completedAt: null
labels: ["architecture", "network", "w3c", "interceptor"]
order: "a5"
---

# Task 5: Network W3C Traceparent Header Injection

Epic Reference: [pulse_logger](pulse_logger.en.md)

## Requirement Analysis
Upgrade `LoggingInterceptor` in `Packages/Network` to integrate with `D3NexusLogger`. Automatically inject the standard W3C `traceparent` header (`00-{traceId}-{spanId}-01`) on all outgoing HTTP requests, record response duration and payload sizing metrics, and automatically redact sensitive credentials (`Authorization`, `Cookie`, `X-API-Key`).

## Relevant Files & Context Pointers
- `Packages/Network/Package.swift`
- `Packages/Network/Sources/Network/Interceptor/LoggingInterceptor.swift`
- `Packages/Network/Tests/NetworkTests/LoggingInterceptorTests.swift`
- `Packages/Logging/Sources/Logging/Facade/D3NexusLogger.swift`

## Design Rationale
- `Packages/Network/Package.swift`: Add dependency on `Packages/Logging`.
- `LoggingInterceptor`:
  - Uses `D3NexusLogger.getLogger("Network").withSpan()` to obtain a child span for each HTTP request.
  - Constructs `traceparent: 00-\(childLogger.traceId)-\(childLogger.spanId)-01` and sets it on `URLRequest`.
  - On request: Logs HTTP method and URL with redacted headers.
  - On response: Logs HTTP status code, duration (ms), byte size, and error status for 4xx/5xx responses.
Applicable Skills: `security-audit`, `architecture-audit`.

## Impact Analysis & Blast Radius
- **Target Files & Symbols**:
  - `LoggingInterceptor` struct
  - `Packages/Network/Package.swift`
- **Downstream Callers**: `APIClient` network execution pipeline.
- **Cross-Platform Bridges**: Backend APM systems receiving W3C `traceparent` headers.
- **Target Test Coverage Threshold**: $\ge 90\%$ line coverage on `LoggingInterceptor`.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

```gherkin
[Tier A - Unit]
Scenario: Automatically inject valid W3C traceparent header into outgoing request
  Given an APIClient configured with LoggingInterceptor and mock transport
  When a GET request to "/cards" is intercepted
  Then the request headers contain "traceparent"
  And the "traceparent" header matches the regex "^00-[0-9a-f]{32}-[0-9a-f]{16}-01$"

[Tier A - Unit]
Scenario: Redact sensitive authorization headers from request log output
  Given an outgoing URLRequest with header "Authorization: Bearer secret_token_123"
  When the LoggingInterceptor logs the request
  Then the emitted log string masks the token as "Bearer [REDACTED]"
  And the raw token "secret_token_123" is never present in log records

[Tier A - Unit]
Scenario: Log response timing metrics and error severity on 500 server error
  Given an intercepted HTTP request returning status 500 after 120ms
  When LoggingInterceptor handles the response
  Then an error-level log record is emitted
  And metadata includes "statusCode" = "500" and duration information
```

## Test & Verification Checklist
- [ ] **RED**: Update `LoggingInterceptorTests.swift` with failing unit tests covering `traceparent` generation, header redaction, and response metrics.
- [ ] **GREEN**: Update `LoggingInterceptor.swift` and `Packages/Network/Package.swift` to pass tests.
- [ ] **REFACTOR**: Execute `swift test --package-path Packages/Network`, format code, and verify zero linter warnings.

## Definition of Done (DoD)
- Outgoing requests carry valid `traceparent` header.
- Sensitive headers are sanitized in 100% of cases.
- All unit tests in `Packages/Network` pass.

## Dependencies & Blockers
- Blocked by: [Task 2](task_2_log_manager_and_facade.md), [Task 4](task_4_core_logger_adapter.md).
- Blocks: [Task 7](task_7_acceptance_and_governance.md).

## References & Rollback
- References: W3C Trace Context Specification (<https://www.w3.org/TR/trace-context/>).
- Rollback: Revert `Packages/Network/Sources/Network/Interceptor/LoggingInterceptor.swift`.
