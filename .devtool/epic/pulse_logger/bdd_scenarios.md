# BDD Acceptance Scenarios — Pulse Logger for iOS

This document serves as the living behavioral contract for the `pulse_logger` epic across the **Mandatory 5-Dimension Boundary Matrix**, providing dense context for engineers and AI agents during implementation and verification.

---

## Use Case 1: Emit Structured Log with W3C Trace

### 1.1 Happy Path
```gherkin
[Tier A - Unit]
Scenario: Successfully emit a structured log record with auto-generated W3C identifiers
  Given a D3NexusLogger instance configured for module "Wallet"
  When the developer invokes d("Transaction initiated", metadata: ["amount": "100.00"])
  Then a LogRecord is created with level .debug, module "Wallet", and message "Transaction initiated"
  And the LogRecord contains a valid 32-character hex traceId and a 16-character hex spanId
  And the LogRecord parentSpanId is nil
  And the metadata contains "amount" with value "100.00"
```

### 1.2 Edge Cases & Boundaries
```gherkin
[Tier A - Unit]
Scenario: Emit a log record with empty message and empty metadata
  Given a D3NexusLogger instance for module "Core"
  When the developer logs an empty string "" with no error and empty metadata
  Then a LogRecord is dispatched containing an empty string message
  And no exception or fatalError is thrown
  And traceId and spanId remain valid hex strings
```

```gherkin
[Tier A - Unit]
Scenario: Emit an error log with an underlying Swift Error and non-empty description
  Given a D3NexusLogger instance for module "Network"
  When the developer calls e("Request failed", error: NetworkError.timeout)
  Then the LogRecord carries errorDescription matching "timeout"
  And the level is .error
```

---

## Use Case 2: Spawn Child Span via `withSpan()`

### 2.1 Happy Path
```gherkin
[Tier A - Unit]
Scenario: Spawn child logger and preserve trace lineage
  Given an active root logger with traceId "4bf92f3577b34da6a3ce929d0e0e4736" and spanId "00f067aa0ba902b7"
  When withSpan() is called on the root logger
  Then the returned child logger preserves the exact traceId "4bf92f3577b34da6a3ce929d0e0e4736"
  And the child logger receives a newly generated 16-character hex spanId different from the root spanId
  And any record emitted by the child logger sets parentSpanId equal to "00f067aa0ba902b7"
```

### 2.2 Deep Nesting Lineage
```gherkin
[Tier A - Unit]
Scenario: Nested spans across 3 layers (UseCase -> Repository -> DataSource)
  Given a root logger in a UseCase with spanId "span_1"
  When a child logger is spawned in Repository with spanId "span_2"
  And a grand-child logger is spawned in DataSource with spanId "span_3"
  Then the grand-child logger parentSpanId is "span_2"
  And the Repository logger parentSpanId is "span_1"
  And all three loggers share the exact same traceId
```

---

## Use Case 3: Reconstruct Hierarchical Trace Tree

### 3.1 Happy Path
```gherkin
[Tier A - Unit]
Scenario: Reconstruct hierarchical tree from ordered parent-child records
  Given a list of 3 log records:
    | ID | SpanId | ParentSpanId | Message |
    | 1  | span_A | nil          | Root operation |
    | 2  | span_B | span_A       | Child operation 1 |
    | 3  | span_C | span_B       | Grandchild operation |
  When buildTraceTree is executed
  Then the result contains exactly 1 root TraceNode corresponding to ID 1
  And root node ID 1 has 1 child corresponding to ID 2
  And child node ID 2 has 1 child corresponding to ID 3
```

### 3.2 Edge Cases & Boundaries (Orphan Spans & Reordering)
```gherkin
[Tier A - Unit]
Scenario: Handle orphan records without crashing when parent span is missing
  Given a list of 2 log records:
    | ID | SpanId | ParentSpanId | Message |
    | 1  | span_X | span_UNKNOWN | Orphan step |
    | 2  | span_Y | nil          | Normal root |
  When buildTraceTree is executed
  Then the returned list contains 2 root TraceNodes
  And the orphan record with parentSpanId "span_UNKNOWN" is promoted to a root node without error
  And zero records are dropped
```

```gherkin
[Tier A - Unit]
Scenario: Handle duplicate spanIds safely when multiple calls originate from the same logger instance
  Given multiple log records emitted with the identical spanId "span_SAME"
  When buildTraceTree is executed
  Then all records are retained in the output tree without truncation or data loss
```

---

## Use Case 4: Module and Appender Toggle Matrix

### 4.1 State Transitions & Truth Table Dispatch
```gherkin
[Tier A - Unit]
Scenario Outline: Verify dispatch matrix across Module Toggle and Appender Toggle combinations
  Given an appender with id <AppenderId> and respectsModuleToggle <RespectsToggle>
  And the appender kill-switch for <AppenderId> is <AppenderEnabled>
  And the module toggle for "Wallet" is <ModuleEnabled>
  When a log record for module "Wallet" is submitted
  Then the appender receive count is <ExpectedDispatched>

  Examples:
    | AppenderId | RespectsToggle | AppenderEnabled | ModuleEnabled | ExpectedDispatched |
    | "pulse"    | true           | true            | true          | 1                  |
    | "pulse"    | true           | true            | false         | 0                  |
    | "pulse"    | true           | false           | true          | 0                  |
    | "pulse"    | true           | false           | false         | 0                  |
    | "oslog"    | false          | true            | true          | 1                  |
    | "oslog"    | false          | true            | false         | 1                  |
    | "oslog"    | false          | false           | true          | 0                  |
    | "oslog"    | false          | false           | false         | 0                  |
```

### 4.2 Async / Race Conditions
```gherkin
[Tier A - Unit]
Scenario: Concurrent log dispatch while toggling module enabled status
  Given 100 concurrent asynchronous tasks logging records to module "Network"
  When another thread toggles setModuleEnabled("Network", false) mid-execution
  Then no race condition crash or data corruption occurs
  And LogManagerImpl maintains atomic thread-safe state
```

---

## Use Case 5: Network Interceptor & W3C Header Injection

### 5.1 Happy Path
```gherkin
[Tier C - Integration]
Scenario: Automatically inject traceparent header and record telemetry
  Given an outgoing HTTP request to "https://api.digitalwallet.com/v1/cards"
  And a LoggingInterceptor attached to the Network APIClient
  When the request is intercepted
  Then the request headers contain "traceparent"
  And the "traceparent" header matches the regex "^00-[0-9a-f]{32}-[0-9a-f]{16}-01$"
  And upon receiving HTTP 200 response, a log entry with response duration and byte size is emitted
```

### 5.2 Failure & Security Resilience
```gherkin
[Tier C - Integration]
Scenario: Mask sensitive bearer tokens and credentials in network request logging
  Given an HTTP request carrying header "Authorization: Bearer secret_token_xyz123"
  When the LoggingInterceptor processes the request
  Then the logged header representation displays "Authorization: Bearer [REDACTED]"
  And the raw token "secret_token_xyz123" is never persisted to Pulse or OSLog
```

```gherkin
[Tier C - Integration]
Scenario: Resilient network logging on 500 Internal Server Error
  Given an HTTP request that receives a 500 status code with an empty body
  When the interceptor captures the response
  Then an error log record is emitted with status code 500
  And the app flow completes without throwing an unhandled interceptor exception
```

---

## Use Case 6: In-App Developer Console & Shake Gesture

### 6.1 Happy Path
```gherkin
[Tier C - Integration]
Scenario: Open PulseUI Console sheet on device shake in Debug mode
  Given the application running in DEBUG mode
  When the device shake gesture notification is posted
  Then the view state triggers presentation of the PulseUI ConsoleView sheet
  And the user can inspect live log records and network transactions
```

### 6.2 Compile-time Release Isolation
```gherkin
[Tier B - Governance]
Scenario: Verify PulseUI and shake listener are stripped in Release configuration
  Given a Release archive build of the host application
  When the binary symbols are inspected
  Then no references to PulseUI or debug console presentation sheets exist in the production binary
```

---

## Use Case 7: Memory Leak & Retain Cycle Verification

### 7.1 Unit Teardown Deallocation
```gherkin
[Tier A - Unit]
Scenario: Assert clean deallocation of LogManagerImpl and Appenders on test teardown
  Given an allocated LogManagerImpl with registered PulseAppender and OSLogAppender
  When the test execution block completes and trackForMemoryLeaks is evaluated
  Then all instances are deallocated with zero retain cycles
  And XCTAssertNil verifies instances are nil
```

### 7.2 Zero Circular Retain in Nested Child Loggers
```gherkin
[Tier A - Unit]
Scenario: Verify child loggers spawned by withSpan do not retain parent loggers
  Given a parent LoggerImpl instance
  When childLogger = parentLogger.withSpan() is created
  And parentLogger goes out of scope while childLogger remains in scope
  Then parentLogger is immediately deallocated from memory
  And childLogger functions independently with zero memory leak
```
