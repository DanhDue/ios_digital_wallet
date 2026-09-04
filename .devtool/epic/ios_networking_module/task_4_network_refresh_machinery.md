---
id: "task_4_network_refresh_machinery"
status: "done"
priority: "high"
assignee: null
epic: "ios_networking_module"
dueDate: null
created: "2026-09-04T11:36:40Z"
modified: "2026-09-04T15:54:22Z"
completedAt: "2026-09-04T15:54:22Z"
labels: ["architecture", "network", "interceptor", "auth"]
order: "a4"
---

# Task 4: Network — `RefreshCoordinator` + `RefreshTokenEndpoint` + `RefreshingAuthInterceptor`

Epic: [ios_networking_module](../epic/ios_networking_module/ios_networking_module.en.md)

**Testing tier: A (behavioral).** The core of the epic — race conditions, loop guard, three-case logout.

## Requirement Analysis

New in `Packages/Network/Sources/Network/`:

1. `Interceptor/RefreshCoordinator.swift` — **NEW**, `public actor`
   - holds `private var inFlight: Task<String, Error>?`
   - `func refreshedAccessToken(perform: @Sendable @escaping () async throws -> String) async throws -> String` — first caller starts the task, concurrent callers `await` the same one; `defer { inFlight = nil }` (runs in actor isolation) so a later 401 wave starts a new refresh
   - `public enum RefreshError: Error, Equatable { case invalidGrant, missingRefreshToken, transient }`
2. `Endpoint/RefreshTokenEndpoint.swift` — **NEW**
   - `public struct RefreshTokenEndpoint: Sendable { public let pathSuffix: String ; public init(pathSuffix:) ; public func matches(_ url: URL) -> Bool { url.path.hasSuffix(pathSuffix) } }` — no URL hard-coded
3. `Interceptor/RefreshingAuthInterceptor.swift` — **NEW**, `RequestInterceptor`
   - init: `session: SessionManaging`, `refresher: TokenRefresher`, `coordinator: RefreshCoordinator`, `authEventSink: AuthEventSink?`, `refreshEndpoint: RefreshTokenEndpoint`
   - `adapt(_:)` — attach `Authorization: Bearer <accessToken>` **unless** the request has `X-Auth-Requirement: none` (then strip that header) **or** `refreshEndpoint.matches(url)`
   - `retry(_:dueTo: .unauthorized)` — decision order:
     1. request is the refresh endpoint → `.doNotRetry`; `session.clear()`; `onUnauthorized(reason: .refreshFailed)` *(misconfiguration guard — refresh normally runs through `makeBareAPIClient()`)*
     2. request carries `X-Auth-Retry: 1` → `.doNotRetry`; `session.clear()`; `onUnauthorized(reason: .retryStillUnauthorized)` *(Case 1)*
     3. `session.refreshToken == nil` → `.doNotRetry`; `session.clear()`; `onUnauthorized(reason: .missingRefreshToken)` *(Case 3)*
     4. else `try await coordinator.refreshedAccessToken { perform }`:
        - success → `session.update(accessToken: new, refreshToken: rotated)`; rebuild request with new bearer + `X-Auth-Retry: 1`; `.retry(rebuilt)`
        - `RefreshError.invalidGrant` → `.doNotRetry`; `session.clear()`; `onUnauthorized(reason: .refreshFailed)` *(Case 2)*
        - `RefreshError.transient` → `.doNotRetry`; **no `clear()`, no `onUnauthorized`** — request throws `NetworkError.unauthorized`, session intact
   - `perform` closure (captured `session`, `refresher`): `guard let rt = session.refreshToken else { throw .missingRefreshToken }`; `switch await refresher.refresh(refreshToken: rt) { .success(a, r): session.update(accessToken: a, refreshToken: r); return a ; .failure(.invalidGrant): throw .invalidGrant ; .failure(.transient): throw .transient }`
   - `retry(_:dueTo: .transport)` → `.doNotRetry`; `didReceive` → no-op

`AuthTokenInterceptor` stays in the package for header-only use.

## Relevant Files & Context Pointers

- `Packages/Network/Sources/Network/Interceptor/RefreshCoordinator.swift` — **NEW**
- `Packages/Network/Sources/Network/Interceptor/RefreshingAuthInterceptor.swift` — **NEW**
- `Packages/Network/Sources/Network/Endpoint/RefreshTokenEndpoint.swift` — **NEW**
- `Packages/Network/Sources/Network/APIRequest.swift`, `APIClient.swift` — read (marker headers, retry loop from Task 3)
- `Packages/Core/Sources/Core/Auth/TokenRefresher.swift`, `Session/SessionManager.swift`, `Auth/AuthEventSink.swift` — read (seams from Tasks 1–2)
- `Packages/Network/Tests/NetworkTests/`: **NEW** `RefreshCoordinatorTests.swift`, `RefreshingAuthInterceptorTests.swift`; **EDIT** `CancellationTests.swift`; helpers `URLProtocolStub.swift`, `TestSupport.swift`; a `SpyTokenRefresher` + `SpyAuthEventSink` in `TestSupport`
- Spec §3.2 (`RefreshCoordinator`, `RefreshingAuthInterceptor`, `RefreshTokenEndpoint`), §4 (sequence + force-logout table), §6 (test list)

## Design Rationale

`actor` single-flight is the Swift-6-native equivalent of Flutter's `isRefreshing` mutex + queue: concurrent 401s `await` one `Task`, so the refresh endpoint is hit once and all callers get the rotated token. The three-case force-logout maps 1:1 to `refresh_token.md` §6. `.transient` deliberately does **not** log out — a flaky network during refresh must not end the session. `makeBareAPIClient()` (Task 6) breaks the recursion; the "refresh endpoint" branch here is a guard for misconfiguration. **Applicable skill: `superpowers:test-driven-development`.**

## TDD Checklist

- [ ] **RED**: BDD scenarios → 1:1 tests
  - `RefreshCoordinatorTests`: N concurrent `refreshedAccessToken` calls invoke `perform` exactly once, all observe the same token; the in-flight task is cleared afterwards (a later call runs `perform` again); a throwing `perform` propagates to every awaiter.
  - `RefreshingAuthInterceptorTests`:
    - happy path — 401 → refresh → `.retry` with new bearer + `X-Auth-Retry: 1`; resend → 200
    - rotation — `.success(_, "r2")` ⇒ `session.refreshToken == "r2"`
    - Case 1 — retried request 401 again ⇒ `.doNotRetry`, `onUnauthorized(.retryStillUnauthorized)`, `session.clear()`, `refresher` **not** called a second time
    - Case 2a — `refresher` → `.failure(.invalidGrant)` ⇒ `.doNotRetry`, `onUnauthorized(.refreshFailed)`, `clear()`
    - Case 2b — request to the refresh endpoint returns 401 ⇒ same as 2a; `refresher` never called
    - Case 3 — `session.refreshToken == nil` at 401 ⇒ `onUnauthorized(.missingRefreshToken)`; `refresher` never called
    - transient — `refresher` → `.failure(.transient)` ⇒ `.doNotRetry`, **no** `onUnauthorized`, session intact
    - whitelist — `authRequirement == .none` ⇒ no `Authorization` header even when `session.accessToken != nil`; `X-Auth-Requirement` stripped before send
    - refresh-endpoint requests never get a bearer
  - `CancellationTests` (edit) — cancelling the task while awaiting `coordinator` throws `CancellationError` (not mapped to `.unauthorized`, not swallowed)
- [ ] **GREEN**: implement the actor, endpoint matcher, and interceptor.
- [ ] **REFACTOR**: extract the request-rebuild (new bearer + retry marker) into a small helper; keep the decision ladder linear and commented with the case numbers.

## Definition of Done (DoD)

- `swift test --package-path Packages/Network` green; all pre-existing `NetworkTests` pass.
- Lint/format clean from repo root; `ArchTests` green (K7).
- One commit: `[IOS_SUPER_APP_TEMPLATE] Network: single-flight RefreshCoordinator + RefreshingAuthInterceptor`.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_core_token_refresher_seam.md), [Task 2](task_2_core_session_refresh_persistence.md), [Task 3](task_3_network_retry_hook.md).
- Blocks [Task 6](task_6_app_network_composition_wiring.md).

## References & Rollback

- Flutter `refresh_token.md` §1 (race condition, loop), §2 (rotation), §6 (three logout cases).
- Rollback: revert the commit — the three new files disappear; `AuthTokenInterceptor` (from Task 3) remains as the header-only + bare-401 path, so the app still builds.
