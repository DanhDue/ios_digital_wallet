---
id: "task_1_core_token_refresher_seam"
status: "todo"
priority: "high"
assignee: null
epic: "ios_networking_module"
dueDate: null
created: "2026-09-04T11:36:40Z"
modified: "2026-09-04T11:36:40Z"
completedAt: null
labels: ["architecture", "core", "auth"]
order: "a1"
---

# Task 1: Core — `TokenRefresher` DIP seam + `LogoutReason`

Epic: [ios_networking_module](../epic/ios_networking_module/ios_networking_module.en.md)

**Testing tier: A (behavioral).**

## Requirement Analysis

`Network` must be able to trigger a token refresh without importing any feature. Introduce the Dependency-Inversion seam in `Core` (alongside the existing `AuthEventSink`), plus a default no-op implementation so a domain-neutral template force-logs-out honestly until a real adapter is wired.

New in `Packages/Core/Sources/Core/Auth/`:

- `TokenRefresher.swift`
  - `public protocol TokenRefresher: Sendable { func refresh(refreshToken: String) async -> TokenRefreshResult }`
  - `public enum TokenRefreshResult: Sendable { case success(accessToken: String, refreshToken: String?) ; case failure(TokenRefreshFailure) }`
  - `public enum TokenRefreshFailure: Sendable, Equatable { case invalidGrant ; case transient }`
  - `public struct NoTokenRefresher: TokenRefresher { public init() {} ; func refresh(...) async -> .failure(.invalidGrant) }`

Edit `Packages/Core/Sources/Core/Auth/AuthEventSink.swift` (additive):

- `public enum LogoutReason: Sendable, Equatable { case unauthorized, refreshFailed, retryStillUnauthorized, missingRefreshToken }`
- `func onUnauthorized(reason: LogoutReason)` becomes the protocol requirement
- `public extension AuthEventSink { func onUnauthorized() { onUnauthorized(reason: .unauthorized) } }` — keeps every existing parameterless call-site (`URLSessionAPIClient`, tests) compiling

## Relevant Files & Context Pointers

- `Packages/Core/Sources/Core/Auth/TokenRefresher.swift` — **NEW**
- `Packages/Core/Sources/Core/Auth/AuthEventSink.swift` — **EDIT** (additive)
- `Packages/Core/Tests/CoreTests/TokenRefresherTests.swift` — **NEW**
- `Packages/Core/Tests/CoreTests/ProtocolSeamsTests.swift` — **EDIT** (assert the back-compat overload)
- Spec: `.devtool/epic/ios_networking_module/2026-09-04-ios-networking-module-design.md` §3.1
- Existing seam pattern to mirror: `Packages/Core/Sources/Core/Auth/AuthEventSink.swift` (current), `Packages/Core/Sources/Core/Session/SessionManager.swift`

## Design Rationale

Mirrors the Flutter `TokenRefresher` interface in `refresh_token.md` §7 (DIP: core depends on the abstraction, the feature owns the adapter). `Sendable` because `Network` calls it off the main actor. `NoTokenRefresher` returns `.invalidGrant` (not `.transient`) so an unwired app force-logs-out on the first `401` rather than silently spinning. `LogoutReason` is additive with a defaulted extension overload — no existing call-site changes. **Applicable skill: `superpowers:test-driven-development`.**

## TDD Checklist

- [ ] **RED**: `TokenRefresherTests` — `NoTokenRefresher().refresh(refreshToken: "x")` returns `.failure(.invalidGrant)`; `TokenRefreshResult` / `TokenRefreshFailure` equatable/case assertions. `ProtocolSeamsTests` — a spy `AuthEventSink` implementing only `onUnauthorized(reason:)` receives `.unauthorized` when the parameterless overload is called.
- [ ] **GREEN**: add the protocol, enums, `NoTokenRefresher`, and the extension overload.
- [ ] **REFACTOR**: doc-comment every public symbol to the house style; confirm no `Foundation` import is needed (pure Swift).

## Definition of Done (DoD)

- `swift build --package-path Packages/Core` and `swift test --package-path Packages/Core` green.
- `swiftlint --strict --config quality/.swiftlint.yml` and `swiftformat --config quality/.swiftformat . --lint` clean from repo root.
- `ArchTests` green (K7: `Core` imports no sibling infra).
- Every existing `CoreTests` case still passes unchanged.
- One commit: `[IOS_SUPER_APP_TEMPLATE] Core: add TokenRefresher DIP seam + LogoutReason`.

## Dependencies & Blockers

- Blocks [Task 4](task_4_network_refresh_machinery.md), [Task 6](task_6_app_network_composition_wiring.md).
- Not blocked by anything.

## References & Rollback

- Flutter `docs/system-design/refresh_token.md` §7 (`TokenRefresher` / `TokenRefreshResult`).
- Rollback: revert the single commit; the new file is additive and nothing else depends on it yet.
