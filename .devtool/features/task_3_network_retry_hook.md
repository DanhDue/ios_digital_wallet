---
id: "task_3_network_retry_hook"
status: "todo"
priority: "high"
assignee: null
epic: "ios_networking_module"
dueDate: null
created: "2026-09-04T11:36:40Z"
modified: "2026-09-04T11:36:40Z"
completedAt: null
labels: ["architecture", "network", "interceptor"]
order: "a3"
---

# Task 3: Network — `retry` hook + `AuthRequirement` + bounded retry in `send`

Epic: [ios_networking_module](../epic/ios_networking_module/ios_networking_module.en.md)

**Testing tier: A (behavioral).**

## Requirement Analysis

Today's `RequestInterceptor` can only observe (`adapt` / `didReceive`). Add a **retry hook** so an interceptor can resend a request (needed by Task 4), and give `APIRequest` a way to opt out of auth. Purely additive — every existing interceptor and test must keep compiling and passing.

Changes in `Packages/Network/Sources/Network/`:

1. `Interceptor/RetryDecision.swift` — **NEW**
   - `public enum RetryReason: Sendable { case unauthorized(HTTPURLResponse) ; case transport(Error) }`
   - `public enum RetryDecision: Sendable { case doNotRetry ; case retry(URLRequest) }`
2. `Interceptor/RequestInterceptor.swift` — **EDIT**
   - add `func retry(_ request: URLRequest, dueTo reason: RetryReason) async -> RetryDecision`
   - `public extension RequestInterceptor { func retry(...) async -> RetryDecision { .doNotRetry } }` — default for `AuthTokenInterceptor` / `LoggingInterceptor`, no edits to them beyond point 5
3. `APIRequest.swift` — **EDIT**
   - `public enum AuthRequirement: Sendable { case required, none }`
   - `let authRequirement: AuthRequirement` (defaulted `.required`, appended last in `init` — source-compatible)
   - `urlRequest(for:)`: when `.none`, set header `X-Auth-Requirement: none`. Shared header-name constants (`X-Auth-Requirement`, `X-Auth-Retry`) live in one internal enum shared with the interceptor.
4. `APIClient.swift` (`URLSessionAPIClient.send`) — **EDIT**
   - after `didReceive` + a failed `validate`, if status is `401` and this is the first attempt, ask each interceptor `retry(request, dueTo: .unauthorized(http))` in order; the first `.retry(newRequest)` → resend **exactly once** (carry `X-Auth-Retry: 1`), then re-`validate` / decode as today. Never more than one resend.
   - **Remove** the `authEventSink?.onUnauthorized()` call from `validate`. Cancellation checks stay.
5. `Interceptor/AuthTokenInterceptor.swift` — **EDIT** (small)
   - gains an optional `AuthEventSink?` (defaulted `nil`, appended last — existing construction unaffected)
   - `retry(_:dueTo: .unauthorized)` → calls `authEventSink?.onUnauthorized(reason: .unauthorized)` once, returns `.doNotRetry` (preserves "bare 401 notifies the sink" for apps with no refresh interceptor)

## Relevant Files & Context Pointers

- `Packages/Network/Sources/Network/Interceptor/RetryDecision.swift` — **NEW**
- `Packages/Network/Sources/Network/Interceptor/RequestInterceptor.swift` — **EDIT**
- `Packages/Network/Sources/Network/Interceptor/AuthTokenInterceptor.swift` — **EDIT**
- `Packages/Network/Sources/Network/APIRequest.swift` — **EDIT**
- `Packages/Network/Sources/Network/APIClient.swift` — **EDIT**
- `Packages/Network/Tests/NetworkTests/`: **NEW** `APIClientRetryTests.swift`; **EDIT** `APIRequestBuildTests.swift`, `InterceptorOrderTests.swift`, `UnauthorizedTests.swift`, `AuthTokenInterceptorTests.swift`; helpers `URLProtocolStub.swift`, `TestSupport.swift`, `StubbedClientTestCase.swift`
- Spec §3.2 (`RetryDecision`, `RequestInterceptor` edit, `APIRequest` edit, `send` edit), §5 (error table)

## Design Rationale

An additive default-implemented protocol method is the least invasive way to reach Dio-parity for "retry / short-circuit". Moving the 401→sink notification out of `URLSessionAPIClient.validate` into `AuthTokenInterceptor.retry` puts the "why is this 401 terminal" decision in the one place that knows — and Task 4's `RefreshingAuthInterceptor` then owns it fully. Marker headers are an in-process channel, stripped before the request leaves; isolated to `APIRequest` + the interceptors. **Applicable skill: `superpowers:test-driven-development`.**

## TDD Checklist

- [ ] **RED**:
  - `APIClientRetryTests` — stub returns 401 then 200; a test interceptor returns `.retry(req)` on `.unauthorized`; `send` yields the decoded 200 body and the stub saw exactly 2 requests. A second 401 (interceptor still `.retry`) → `send` throws `.unauthorized`, stub saw exactly 2 (no infinite retry). Non-401 non-2xx is never passed to `retry`.
  - `APIRequestBuildTests` (edit) — `.none` ⇒ outgoing `URLRequest` has `X-Auth-Requirement: none`; `.required` ⇒ absent.
  - `InterceptorOrderTests` (edit) — adding `retry` does not change `adapt` / `didReceive` call order; `retry` is called in registration order and stops at the first `.retry`.
  - `UnauthorizedTests` / `AuthTokenInterceptorTests` (edit) — with `AuthTokenInterceptor(session:authEventSink:)` and no refresh interceptor, a bare 401 calls `onUnauthorized(reason: .unauthorized)` exactly once and `send` throws `.unauthorized`.
- [ ] **GREEN**: implement points 1–5.
- [ ] **REFACTOR**: keep `send` readable — extract the retry loop into a private helper; ensure `Task.checkCancellation()` still bounds both attempts.

## Definition of Done (DoD)

- `swift test --package-path Packages/Network` green; **all pre-existing `NetworkTests` pass** (edited files included, semantics preserved).
- Lint/format clean from repo root; `ArchTests` green (K7: `Network` imports only `Core`).
- One commit: `[IOS_SUPER_APP_TEMPLATE] Network: add interceptor retry hook + APIRequest.authRequirement`.

## Dependencies & Blockers

- Blocks [Task 4](task_4_network_refresh_machinery.md), [Task 7](task_7_mason_has_network_scaffold.md).
- Not blocked.

## References & Rollback

- Flutter `refresh_token.md` §5 (public-endpoint whitelist), §1 Vấn đề 2 (loop guard via `is_retry`).
- Rollback: revert the commit — `RequestInterceptor` loses `retry`, `APIRequest` loses `authRequirement`, `send` loses the retry loop, and the 401→sink call returns to `validate`. `NetworkTests` edits revert with it.
