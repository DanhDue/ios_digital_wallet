# BDD Acceptance Scenarios — Pulse Logger for iOS

The living behavioural contract for the `pulse_logger` epic, across the mandatory 5-dimension
boundary matrix (happy path · edge & boundary · state transition · async & race · failure &
resilience).

**Authority:** derived from [`pulse_logger.en.md`](pulse_logger.en.md) §5.1–§5.3 only — the Use
Cases, the architecture diagram and the sequence diagram. Written adversarially, before and
independently of any implementation. Where the source spec's code samples conflict, §3 of the HLD
(Deviations) governs.

**Naming note:** the package and module are `AppLogging`; logger methods are
`debug` / `info` / `warning` / `error` / `verbose` (HLD D1, D2).

---

## UC-1 · Emit structured log with W3C trace

### 1.1 Happy path
```gherkin
[Tier A - Unit]
Scenario: Emit a structured record with auto-generated W3C identifiers
  Given a AppLogger obtained for module "Settings"
  When the caller invokes debug("Transaction initiated", metadata: ["amount": "100.00"])
  Then a LogRecord is dispatched with level .debug, module "Settings" and the given message
  And traceId matches "^[0-9a-f]{32}$"
  And spanId matches "^[0-9a-f]{16}$"
  And parentSpanId is nil
  And metadata["amount"] equals "100.00"
```

```gherkin
[Tier A - Unit]
Scenario Outline: Every severity maps to the correct LogLevel
  Given a logger for module "Core"
  When the caller invokes <Method>("msg")
  Then the dispatched LogRecord has level <Level>

  Examples:
    | Method  | Level     |
    | verbose | .verbose  |
    | debug   | .debug    |
    | info    | .info     |
    | warning | .warning  |
    | error   | .error    |
```

### 1.2 Edge cases & boundaries
```gherkin
[Tier A - Unit]
Scenario: Empty message and empty metadata are accepted
  Given a logger for module "Core"
  When the caller logs an empty string with no error and empty metadata
  Then a LogRecord carrying an empty message is dispatched
  And no trap, precondition failure or crash occurs
  And traceId and spanId are still well-formed hex
```

```gherkin
[Tier A - Unit]
Scenario: A very long message is neither truncated nor allowed to corrupt the record
  Given a logger for module "Network"
  When the caller logs a 64 KB message
  Then the LogRecord message length equals the input length
  And dispatch to every registered appender still completes
```

```gherkin
[Tier A - Unit]
Scenario: An underlying Error is captured as errorDescription without losing the message
  Given a logger for module "Network"
  When the caller invokes error("Request failed", error: NetworkError.timeout)
  Then the LogRecord level is .error
  And message equals "Request failed"
  And errorDescription is non-nil and describes the timeout
```

```gherkin
[Tier A - Unit]
Scenario: Two identifiers generated back to back are distinct
  Given the trace identifier generator
  When 10000 spanIds are generated in a tight loop
  Then every value matches "^[0-9a-f]{16}$"
  And the number of distinct values equals 10000
  # Guards HLD D6: UUID().uuidString.prefix(16) would embed "-" and fail the regex.
```

### 1.3 Failure & resilience
```gherkin
[Tier A - Unit]
Scenario: An appender that throws does not prevent the remaining appenders from receiving the record
  Given a LogManagerImpl with a failing appender registered before a healthy appender
  When a record is logged
  Then the healthy appender still receives exactly 1 record
  And the failure is contained rather than propagated to the caller
```

---

## UC-2 · Spawn child span via `withSpan()`

### 2.1 Happy path
```gherkin
[Tier A - Unit]
Scenario: Child logger preserves the trace and links the parent span
  Given a root logger with traceId "4bf92f3577b34da6a3ce929d0e0e4736" and spanId "00f067aa0ba902b7"
  When withSpan() is called
  Then the child logger reports the same traceId
  And the child spanId matches "^[0-9a-f]{16}$" and differs from the parent spanId
  And every record emitted by the child carries parentSpanId "00f067aa0ba902b7"
```

### 2.2 Deep nesting
```gherkin
[Tier A - Unit]
Scenario: Lineage is preserved across three nested layers
  Given a root logger in a UseCase
  When a child is spawned in a Repository and a grandchild in a DataSource
  Then the grandchild parentSpanId equals the child spanId
  And the child parentSpanId equals the root spanId
  And all three share one traceId
```

### 2.3 Memory safety (state transition)
```gherkin
[Tier A - Unit]
Scenario: A child logger does not keep its parent alive
  Given a parent logger instance tracked for memory leaks
  When child = parent.withSpan() is created and the parent reference is released
  Then the parent is deallocated immediately
  And the child continues to emit records carrying the recorded parentSpanId
  # The child stores parentSpanId as a String value, never a reference (HLD Goal 7).
```

### 2.4 Async & race
```gherkin
[Tier A - Unit]
Scenario: Concurrent span creation produces no duplicate span identifiers
  Given one root logger
  When 500 concurrent tasks each call withSpan() once
  Then 500 distinct spanIds are produced
  And every one of them reports the root traceId
```

---

## UC-3 · Inject `traceparent` into HTTP request

### 3.1 Happy path
```gherkin
[Tier A - Unit]
Scenario: TraceContextInterceptor adds a well-formed traceparent header
  Given a TraceContextInterceptor built over a stub TraceContextProviding
  When adapt(_:) is awaited for a request to "https://example.com/v1/cards"
  Then the returned URLRequest carries a "traceparent" header
  And the header matches "^00-[0-9a-f]{32}-[0-9a-f]{16}-01$"
  And no other header of the original request is modified
```

### 3.2 Edge cases & boundaries
```gherkin
[Tier A - Unit]
Scenario: A request that already carries traceparent is not double-stamped
  Given an outgoing request that already has a "traceparent" header from an upstream caller
  When adapt(_:) is awaited
  Then exactly one "traceparent" header is present on the result
```

```gherkin
[Tier A - Unit]
Scenario: A nil trace context leaves the request untouched rather than emitting a malformed header
  Given a TraceContextProviding stub that returns nil
  When adapt(_:) is awaited
  Then the returned request carries no "traceparent" header
  And the request is still dispatched normally
```

### 3.3 Architecture constraint
```gherkin
[Tier B - Governance]
Scenario: Network reaches trace context only through the Core seam
  Given the SPM manifest at Packages/Network/Package.swift
  When its dependency list is inspected
  Then it declares Core and nothing else
  And no file under Packages/Network/Sources imports AppLogging
  # Enforces HLD D4: the Layer 3 one-way DAG stays intact.
```

### 3.4 Failure & resilience
```gherkin
[Tier A - Unit]
Scenario: didReceive reports status without body or timing, by design
  Given an intercepted response with status 500 and an empty body
  When didReceive(_:) is invoked
  Then an error-level record is emitted naming status 500
  And no attempt is made to read a response body
  And the call returns without throwing
  # RequestInterceptor.didReceive is synchronous and body-less (HLD D3).
```

---

## UC-4 · Toggle module or appender

### 4.1 State transitions — dispatch truth table
```gherkin
[Tier A - Unit]
Scenario Outline: Dispatch across module toggle x appender toggle x respectsModuleToggle
  Given an appender <AppenderId> whose respectsModuleToggle is <RespectsToggle>
  And the appender kill-switch for <AppenderId> is <AppenderEnabled>
  And the module toggle for "Settings" is <ModuleEnabled>
  When a record for module "Settings" is submitted
  Then the appender receive count is <Dispatched>

  Examples:
    | AppenderId | RespectsToggle | AppenderEnabled | ModuleEnabled | Dispatched |
    | "pulse"    | true           | true            | true          | 1          |
    | "pulse"    | true           | true            | false         | 0          |
    | "pulse"    | true           | false           | true          | 0          |
    | "pulse"    | true           | false           | false         | 0          |
    | "oslog"    | false          | true            | true          | 1          |
    | "oslog"    | false          | true            | false         | 1          |
    | "oslog"    | false          | false           | true          | 0          |
    | "oslog"    | false          | false           | false         | 0          |
```

### 4.2 Persistence
```gherkin
[Tier A - Unit]
Scenario: Toggles survive a process restart
  Given module "Scanner" is muted and appender "pulse" is disabled
  When the toggle store is rebuilt from the same UserDefaults suite
  Then isModuleEnabled("Scanner") is false
  And isAppenderEnabled("pulse") is false
  And the values are stored under "logging.module_toggles" and "logging.appender_toggles"
```

```gherkin
[Tier A - Unit]
Scenario: A module never configured defaults to enabled
  Given an empty UserDefaults suite
  When isModuleEnabled("NeverSeen") is queried
  Then it returns true
```

```gherkin
[Tier A - Unit]
Scenario: Corrupted persisted toggle data falls back to defaults instead of crashing
  Given "logging.module_toggles" holds a value of the wrong type
  When the toggle store is initialised
  Then initialisation succeeds
  And every module reports enabled
```

### 4.3 Async & race
```gherkin
[Tier A - Unit]
Scenario: Toggling mid-flight neither crashes nor corrupts state
  Given 100 concurrent tasks logging to module "Network"
  When another task flips setModuleEnabled("Network", false) during the burst
  Then no data race, crash or corrupted toggle state is observed
  And the final persisted value is deterministic
```

---

## UC-5 · Open in-app console via shake

### 5.1 Happy path
```gherkin
[Tier C - Integration]
Scenario: Shake presents the PulseUI console in a DEBUG build
  Given the app running in DEBUG
  When the device-shake notification is posted
  Then the console presentation state becomes true
  And the console lists the records captured so far
```

### 5.2 Edge cases
```gherkin
[Tier C - Integration]
Scenario: Repeated shakes while the console is open do not stack sheets
  Given the console is already presented
  When three further shake notifications are posted
  Then exactly one console presentation remains
```

### 5.3 Compile-time release isolation
```gherkin
[Tier B - Governance]
Scenario: PulseUI and the shake listener are absent from a Release build
  Given a Release configuration build of the host app
  When the produced binary and the linked frameworks are inspected
  Then no PulseUI symbol is present
  And no shake-notification observer is registered
```

---

## UC-6 · Reconstruct hierarchical trace tree

### 6.1 Happy path
```gherkin
[Tier A - Unit]
Scenario: Build a three-level tree from ordered records
  Given records:
    | ID | SpanId | ParentSpanId |
    | 1  | span_A | nil          |
    | 2  | span_B | span_A       |
    | 3  | span_C | span_B       |
  When buildTraceTree is executed
  Then exactly 1 root is returned, corresponding to ID 1
  And that root has 1 child (ID 2) which has 1 child (ID 3)
```

### 6.2 Edge cases & boundaries
```gherkin
[Tier A - Unit]
Scenario: Records arriving out of order still form the correct tree
  Given the same three records supplied in the order 3, 1, 2
  When buildTraceTree is executed
  Then the resulting tree is identical to the in-order result
```

```gherkin
[Tier A - Unit]
Scenario: An orphan is promoted to a root and nothing is dropped
  Given records:
    | ID | SpanId | ParentSpanId  |
    | 1  | span_X | span_UNKNOWN  |
    | 2  | span_Y | nil           |
  When buildTraceTree is executed
  Then 2 roots are returned
  And the total node count across the forest equals 2
```

```gherkin
[Tier A - Unit]
Scenario: An empty input yields an empty forest
  Given an empty record list
  When buildTraceTree is executed
  Then the result is empty and no error is raised
```

```gherkin
[Tier A - Unit]
Scenario: Records sharing one spanId are all retained
  Given 5 records all carrying spanId "span_SAME"
  When buildTraceTree is executed
  Then the total node count across the forest equals 5
```

### 6.3 Failure & resilience — the cycle guard
```gherkin
[Tier A - Unit]
Scenario: A two-record cycle terminates instead of recursing forever
  Given records:
    | ID | SpanId | ParentSpanId |
    | 1  | span_P | span_Q       |
    | 2  | span_Q | span_P       |
  When buildTraceTree is executed
  Then the call returns within the test timeout
  And both records appear exactly once in the forest
  And no node is reachable from itself
  # Guards HLD D7 — the source spec's algorithm would recurse forever and leak.
```

```gherkin
[Tier A - Unit]
Scenario: A record that is its own parent is treated as a root
  Given one record whose spanId and parentSpanId are both "span_S"
  When buildTraceTree is executed
  Then 1 root is returned and it has no children
```

```gherkin
[Tier A - Unit]
Scenario: A deep chain does not overflow the stack
  Given a chain of 10000 records each parented to the previous one
  When buildTraceTree is executed
  Then the call completes without stack overflow
  And every record is present in the forest
```

---

## UC-7 · Assert zero memory leaks on teardown

### 7.1 Unit teardown
```gherkin
[Tier A - Unit]
Scenario: Manager and appenders deallocate cleanly
  Given a LogManagerImpl with an OSLogAppender and a spy appender registered
  And every instance is tracked with trackForMemoryLeaks
  When the test completes and teardown blocks run
  Then every tracked instance is nil
```

```gherkin
[Tier A - Unit]
Scenario: Registering an appender does not create a back-reference cycle
  Given an appender holding a reference to the manager that owns it
  When both are released at end of test
  Then both deallocate
```

### 7.2 Tier C runtime gate
```gherkin
[Tier C - Integration]
Scenario: A host-app session shows no retained logging graph
  Given the host app launched under the test scheme with MallocStackLogging enabled
  When a navigation flow that emits logs and performs a request completes
  And the leaks check runs against the process
  Then zero leaked logging objects are reported
```

---

## UC-8 · Redact secrets and PII before persistence

### 8.1 Happy path — header masking
```gherkin
[Tier A - Unit]
Scenario Outline: Sensitive headers are masked
  Given a record whose metadata contains header <Header> with value <Raw>
  When the record passes through the Redactor
  Then the emitted value for <Header> is "[REDACTED]"
  And <Raw> appears nowhere in the sanitised record

  Examples:
    | Header          | Raw                    |
    | "Authorization" | "Bearer secret_xyz123" |
    | "Cookie"        | "session=abc123"       |
    | "X-API-Key"     | "k-live-9931"          |
    | "Session-Token" | "st-7741"              |
```

```gherkin
[Tier A - Unit]
Scenario: Header matching is case-insensitive
  Given a record carrying "authorization" in lower case
  When the record passes through the Redactor
  Then the value is masked exactly as the canonical spelling would be
```

### 8.2 Pattern redaction
```gherkin
[Tier A - Unit]
Scenario Outline: Financial and authentication patterns are masked inside free text
  Given a log message containing <Sample>
  When the record passes through the Redactor
  Then <Sample> does not appear in the sanitised message
  And a masked placeholder appears in its place

  Examples:
    | Sample                |
    | "4111 1111 1111 1111" |
    | "4111-1111-1111-1111" |
    | "4111111111111111"    |
```

```gherkin
[Tier A - Unit]
Scenario: Non-sensitive numbers that merely resemble a PAN are not destroyed
  Given a message containing an order reference "1234"
  When the record passes through the Redactor
  Then "1234" is preserved
  # Boundary: over-redaction makes logs useless; the rule must be anchored.
```

```gherkin
[Tier A - Unit]
Scenario: Redaction is applied once at the manager boundary, so every appender is covered
  Given a LogManagerImpl with two spy appenders registered
  When a record containing a bearer token is logged
  Then neither spy appender ever observes the raw token
```

### 8.3 Failure & resilience
```gherkin
[Tier A - Unit]
Scenario: A record with no sensitive content passes through unchanged
  Given a record with a plain message and plain metadata
  When the record passes through the Redactor
  Then the output equals the input
```

```gherkin
[Tier A - Unit]
Scenario: Redaction of a large payload stays within the performance budget
  Given a 256 KB message containing 100 card-number-shaped substrings
  When the record passes through the Redactor
  Then all 100 are masked
  And the operation completes within the documented budget
```

---

## UC-9 · Capture network timing, body and cURL

### 9.1 Happy path
```gherkin
[Tier C - Integration]
Scenario: The instrumented session records a completed transaction
  Given the host app composed with a Pulse-instrumented URLSession
  When a request to a stubbed endpoint returns 200 with a JSON body
  Then the captured entry records the request duration
  And it records the response byte count
  And it exposes the decoded JSON body for inspection
  And a cURL representation of the request can be exported
  # These come from the URLSession layer, not the interceptor chain (HLD D3, D5).
```

### 9.2 Security boundary
```gherkin
[Tier C - Integration]
Scenario: Captured network bodies and headers are redacted before they reach storage
  Given a request carrying "Authorization: Bearer secret_token_xyz123"
  And a response body containing a card number
  When the transaction is captured by the instrumented session
  Then the stored entry shows "[REDACTED]" for the authorization header
  And the raw token never reaches the store
  And the card number in the body is masked
```

### 9.3 Failure & resilience
```gherkin
[Tier C - Integration]
Scenario: A transport failure is captured without destabilising the request pipeline
  Given a request that fails with a connection timeout
  When the instrumented session observes the failure
  Then the failure is recorded as an entry
  And the error still surfaces to the caller unchanged
```

```gherkin
[Tier C - Integration]
Scenario: Removing the instrumentation leaves the network stack fully functional
  Given the host app composed with a plain URLSession
  When the same request flow runs
  Then the request succeeds identically
  And no logging-related failure occurs
  # Proves the rollback path in HLD §6 is real.
```

---

## Cross-cutting · Facade and composition safety

```gherkin
[Tier A - Unit]
Scenario: Requesting a logger before initialisation returns a no-op rather than crashing
  Given AppLogger has not been initialised
  When getLogger("Settings") is called in a Release-like configuration
  Then a NoOpLogger is returned
  And logging through it is silently discarded
  And the process does not terminate
  # Guards HLD D8.
```

```gherkin
[Tier A - Unit]
Scenario: Core call sites keep working through the compatibility adapter
  Given a CoreLoggerAdapter injected wherever Core.Logger was previously injected
  When debug, info and error are called with file, function and line
  Then each produces a LogRecord at the matching level
  And the originating file, function and line are preserved in metadata
```

```gherkin
[Tier B - Governance]
Scenario: The architecture gate accepts the new package
  Given the full repository graph including Packages/AppLogging
  When swift test --package-path ArchTests is executed
  Then every K1-K10 rule passes
  And no file under Packages/AppLogging/Sources imports a feature module
  And HostRulesTests lists AppLogging among the siblings Core may not import
```

```gherkin
[Tier B - Governance]
Scenario: Every template mode still generates and builds
  Given the repository
  When the project is generated for enterprise mode and then for lean mode
  Then both generate without error
  And the logging package is present in both dependency lists
  And plugin mode is unaffected
```
