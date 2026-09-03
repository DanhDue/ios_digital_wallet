---
id: "task_6_ios_network_package"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: null
labels: ["architecture", "spm", "network"]
order: "a6"
---

# Task 6: Create `Network` SPM package

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: A (behavioral).** Scenario list is heavy on failure injection and cancellation.

## Requirement Analysis

`Packages/Network/` — depends on `Core` **only** (Changelog #8). URLSession-based, no Alamofire. Mirror of Flutter `packages/network` / Android `:infra:network`.

```
Sources/Network/
├── APIClient.swift            protocol APIClient { func send<T: Decodable>(_ request: APIRequest) async throws -> T }
│                              + URLSessionAPIClient (constructor-injected URLSession + [RequestInterceptor] + Logger + AuthEventSink?)
├── APIRequest.swift           method, path, query, body, headers; builds URLRequest against Environment
├── Environment/
│   ├── Environment.swift      protocol { baseURL, defaultHeaders }
│   └── AppEnvironment.swift   enum debug/staging/production -> https://api.example.com placeholders
├── Interceptor/
│   ├── RequestInterceptor.swift   protocol { func adapt(_ req: URLRequest) async -> URLRequest ; func didReceive(_ resp: HTTPURLResponse) }
│   ├── AuthTokenInterceptor.swift  reads token from Core.SessionManaging (injected), adds Bearer header
│   └── LoggingInterceptor.swift    logs via Core.Logger
├── Error/
│   ├── NetworkError.swift      maps status/transport errors -> Core.AppError
│   └── HTTPStatusCode.swift
└── Mocks/
    └── MockAPIClient.swift     APIClient test double: queue of results + configurable artificialDelay
```

**401 handling:** `URLSessionAPIClient` on a `401` calls `authEventSink?.onUnauthorized()` exactly once per response (not per retry). The sink is wired to `AppEventBus.publish(UserLoggedOut())` in the App composition root (Task 12) — `Network` never imports `Platform`.

## Relevant Files & Context Pointers

- `Packages/Network/Package.swift`, `Packages/Network/Sources/Network/**`, `Packages/Network/Tests/NetworkTests/**` — **NEW**
- `Tuist/Package.swift` — marker-region entry for `Packages/Network`
- Source Spec §4.2, §8 (lifecycle events), Changelog #8 (`AuthEventSink`, no `Network → Platform`)

## Design Rationale

`APIClient` is a protocol so Features test against `MockAPIClient` with no `URLSession` in tests. `MockAPIClient.artificialDelay` lets Feature tests reproduce race conditions deterministically (Source Spec §9A). 401→`AuthEventSink` is Dependency Inversion: the protocol is in `Core`, the concrete publish is in `App`, keeping `Network` a leaf on `Core`.

**Applicable skills:** check `.agents/skills/` for an `api_integration` skill; note it here if present.

### BDD Scenarios

```gherkin
# Happy path
Scenario: GET returns a decoded model on 200 with valid JSON

# Boundary / equivalence
Scenario: 204 No Content with an empty body decodes to Void / EmptyResponse
Scenario: response body is valid JSON but missing a required field -> NetworkError.decoding
Scenario: response body is not JSON -> NetworkError.decoding, raw snippet logged
Scenario: very large (1 MB) JSON array decodes without error
Scenario: query params with reserved characters are percent-encoded exactly once

# State transitions
Scenario: AuthTokenInterceptor adds "Authorization: Bearer <token>" when SessionManaging has a token
Scenario: AuthTokenInterceptor adds no Authorization header when token is nil

# Async / race
Scenario: a request cancelled mid-flight throws CancellationError and performs no interceptor.didReceive
Scenario: two concurrent requests each get their own response (no shared mutable state leak)

# Failure injection
Scenario: transport timeout -> NetworkError.timeout mapped to AppError(code: "timeout")
Scenario: HTTP 500 -> NetworkError.server(500) -> AppError; body logged at error level
Scenario: HTTP 401 -> authEventSink.onUnauthorized() called exactly once; error surfaced to caller
Scenario: HTTP 401 with a client that retries once -> onUnauthorized still called exactly once

# Emission order
Scenario: interceptors run adapt() in registration order, didReceive() in the same order

# Resource teardown
Scenario: URLSession data task is released after the call completes or throws (no leak)
Scenario: MockAPIClient with a queued error then success serves them in order and then throws "no more responses"
```

### TDD Tests

- `MockAPIClientTests` — queued results FIFO; `artificialDelay` respected (measure); exhaustion throws.
- `NetworkErrorMappingTests` — 204 / missing-field / non-JSON / 500 / timeout → expected `AppError` code; spy `Logger` asserts the error log.
- `AuthTokenInterceptorTests` — header present/absent by injected `SessionManaging` state.
- `InterceptorOrderTests` — record `adapt`/`didReceive` call order for 3 interceptors.
- `UnauthorizedTests` — a stub `AuthEventSink` counts `onUnauthorized`; assert == 1 for single call and for retry-once client.
- `CancellationTests` — `Task { try await client.send(...) }.cancel()` → `CancellationError`; `didReceive` not called.
- Use `URLProtocol` stub (in-package) to drive `URLSessionAPIClient` without a network.

### RED → GREEN

- RED: all tests fail against `fatalError()` stubs; the "onUnauthorized exactly once on retry" test fails if the sink is called from the wrong place (e.g. per attempt).
- GREEN: implement `URLSessionAPIClient`, interceptors, `NetworkError` mapping, `MockAPIClient`.

## Definition of Done

- `swift test --package-path Packages/Network` green; every scenario has a passing test.
- `MockAPIClient` usable from other packages' tests.
- 401 → `AuthEventSink.onUnauthorized()` proven exactly-once (incl. retry).
- `Package.swift` deps == `[Core]` (verified). Coverage ≥ 75%. SwiftLint/SwiftFormat clean.

## Dependencies & Blockers

- Blocked by [Task 4](task_4_ios_core_package.md).
- Blocks [Task 11](task_11_ios_settings_feature.md) (Settings is local-only but pulls `Network` for parity) and [Task 12](task_12_ios_scanner_and_composition.md) (App wires the sink).

## References & Rollback

- Source Spec §4.2, §8, Changelog #8.
- Rollback: remove `Packages/Network/` + marker line. `Core` unaffected.
