---
id: "task_6_app_network_composition_wiring"
status: "done"
priority: "high"
assignee: null
epic: "ios_networking_module"
dueDate: null
created: "2026-09-04T11:36:40Z"
modified: "2026-09-04T16:18:16Z"
completedAt: "2026-09-04T16:18:16Z"
labels: ["architecture", "app", "composition", "di"]
order: "a6"
---

# Task 6: App — `NetworkComposition` wiring + `makeBareAPIClient` + Keychain

Epic: [ios_networking_module](../epic/ios_networking_module/ios_networking_module.en.md)

**Testing tier: A (behavioral).**

## Requirement Analysis

Wire the new machinery at the composition root. The template ships `NoTokenRefresher` — so the sample app force-logs-out on a real 401, the honest default for a domain-neutral template.

Edit `App/Sources/Composition/NetworkComposition.swift`:

- `makeAPIClient(...)` gains: `tokenRefresher: any TokenRefresher = NoTokenRefresher()`, `session: any SessionManaging`, `refreshEndpoint: RefreshTokenEndpoint` (a placeholder suffix, e.g. `"auth/refresh"`).
- interceptor list → `[RefreshingAuthInterceptor(session:, refresher:, coordinator: RefreshCoordinator(), authEventSink: BusAuthEventSink(eventBus:), refreshEndpoint:), LoggingInterceptor(logger:)]`
- **NEW** `makeBareAPIClient(...)` — an `APIClient` with **only** `LoggingInterceptor` (no `RefreshingAuthInterceptor`, no `AuthTokenInterceptor`). A consumer's `TokenRefresher` adapter MUST call the refresh endpoint through this client.
- `BusAuthEventSink.onUnauthorized(reason:)` publishes `UserLoggedOut(reason:)`.

Edit `App/Sources/Composition/AppComposition.swift`:

- build `KeychainCacheStore(service: "com.iosdigitalwallet.session")`, pass it to `SessionManager(secureCacheStore:)`
- pass `SessionManager` + `NoTokenRefresher()` into `NetworkComposition`

Edit `Packages/Platform` `UserLoggedOut` event — add an optional `reason` field (additive, defaulted) carrying `Core.LogoutReason`. Update `Platform` tests if any assert its shape.

## Relevant Files & Context Pointers

- `App/Sources/Composition/NetworkComposition.swift` — **EDIT**
- `App/Sources/Composition/AppComposition.swift` — **EDIT**
- `App/Sources/Composition/ConsoleLogger.swift` — read
- `Packages/Platform/Sources/Platform/**` — `UserLoggedOut` (or the events file) — **EDIT** (additive `reason`)
- `Packages/Core/Sources/Core/Cache/SecureCacheStore.swift` (`KeychainCacheStore`), `Session/SessionManager.swift` — read
- `App/Tests/AppTests/AppCompositionTests.swift` — **EDIT**; `App/Tests/AppTests/TestSupport.swift` — read
- Spec §3.3 (`NetworkComposition`, `AppComposition`), §5 (rollout — behavioural-change watch)

## Design Rationale

Constructor injection only (a DI framework is a Non-Goal in `ARCHITECTURE.md`). `makeBareAPIClient()` is the anti-recursion boundary — without it, a 401 from the refresh endpoint re-enters `RefreshingAuthInterceptor.retry` → infinite loop. Keeping `Network` unaware of `Platform`, `BusAuthEventSink` (in `App`) is the only place `LogoutReason` becomes a `UserLoggedOut`. **Applicable skills: `superpowers:test-driven-development`, `superpowers:subagent-driven-development` (if executed via the epic-implementation flow).**

## TDD Checklist

- [ ] **RED**: `AppCompositionTests` (edit) —
  - the composed authed client's interceptors are `[RefreshingAuthInterceptor, LoggingInterceptor]` in that order
  - `makeBareAPIClient()` contains neither `RefreshingAuthInterceptor` nor `AuthTokenInterceptor`
  - `SessionManager` is constructed with a `SecureCacheStore` (Keychain) — assert via an injected fake in the test composition path
  - a stubbed 401 with `NoTokenRefresher` → `BusAuthEventSink` publishes `UserLoggedOut` with `reason == .refreshFailed` on the injected `AppEventBus`
- [ ] **GREEN**: implement the wiring + the additive `UserLoggedOut.reason`.
- [ ] **REFACTOR**: keep `AppComposition.init` readable; group the network wiring into a single private helper if it grows.

## Definition of Done (DoD)

- `swift test --package-path App` (or `xcodebuild test` per repo convention) green; `swift test` for `Packages/Platform` green.
- Full app builds: `tuist generate` + `xcodebuild` on the iPhone 16 simulator.
- Lint/format clean from repo root; `ArchTests` green (K7 unaffected — the wiring is in `App`).
- One commit: `[IOS_SUPER_APP_TEMPLATE] App: wire RefreshingAuthInterceptor + makeBareAPIClient + Keychain session`.

## Dependencies & Blockers

- Blocked by [Task 4](task_4_network_refresh_machinery.md) (needs `RefreshingAuthInterceptor`, `RefreshCoordinator`, `RefreshTokenEndpoint`), transitively [Task 1](task_1_core_token_refresher_seam.md) + [Task 2](task_2_core_session_refresh_persistence.md).
- Blocks [Task 8](task_8_docs_networking_refresh_token.md).

## References & Rollback

- Flutter `refresh_token.md` §7 ("Wiring trong `NetworkModule`", "Dio riêng cho refresh").
- Rollback: revert the commit — `NetworkComposition` returns to its pre-epic single-`APIClient` assembly; the `Core` / `Network` types from Tasks 1–5 stay in place, dormant and still tested. `UserLoggedOut.reason` reverts (was defaulted).
