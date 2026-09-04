---
id: "task_2_core_session_refresh_persistence"
status: "done"
priority: "high"
assignee: null
epic: "ios_networking_module"
dueDate: null
created: "2026-09-04T11:36:40Z"
modified: "2026-09-04T12:06:06Z"
completedAt: "2026-09-04T12:06:06Z"
labels: ["architecture", "core", "session", "keychain"]
order: "a2"
---

# Task 2: Core — `SessionManager` refresh token + Keychain persistence

Epic: [ios_networking_module](../epic/ios_networking_module/ios_networking_module.en.md)

**Testing tier: A (behavioral).**

## Requirement Analysis

`SessionManager` currently holds only an access token, in memory. The refresh flow needs a refresh token that survives app launches, with Refresh Token Rotation (overwrite on every refresh).

Edit `Packages/Core/Sources/Core/Session/SessionManager.swift`:

- `SessionManaging` gains:
  - `var refreshToken: String? { get }`
  - `func update(accessToken: String?, refreshToken: String?)`
  - keep `func update(accessToken: String?)` as a convenience = `update(accessToken:refreshToken:nil)`
  - `clear()` removes **both** tokens
- `SessionManager` gains an **optional** `SecureCacheStore?` (from `Core/Cache/SecureCacheStore.swift`) injected via `init`:
  - store present → `update(...)` writes both tokens as JSON items (`"core.session.access"`, `"core.session.refresh"`); `init` reloads them; `clear()` removes both keys
  - store absent → today's pure `NSLock` in-memory behaviour, byte-for-byte
- **Rotation semantics**: `update(accessToken:refreshToken:)` overwrites the stored refresh token only when `refreshToken != nil`. A routine access-token-only update (`refreshToken: nil`) leaves the stored refresh token intact. Explicit `clear()` is the only way to drop it.

## Relevant Files & Context Pointers

- `Packages/Core/Sources/Core/Session/SessionManager.swift` — **EDIT**
- `Packages/Core/Sources/Core/Cache/SecureCacheStore.swift` — read (reuse `SecureCacheStore` protocol; `KeychainCacheStore` is the production impl)
- `Packages/Core/Tests/CoreTests/SessionManagerTests.swift` — **EDIT** (add persistence/rotation cases; keep existing in-memory cases)
- `Packages/Core/Tests/CoreTests/TestSupport.swift` — add a `FakeSecureCacheStore` (in-memory dictionary conforming to `SecureCacheStore`) if not already present
- Spec §3.1 "`Core/Session/SessionManager.swift` (EDIT)"

## Design Rationale

One type owns the session (mirrors Flutter `AuthLocalDataSource` + in-memory token). Reusing the existing `SecureCacheStore` seam keeps Keychain access testable without a live Keychain. The optional store keeps this change backward-compatible: existing `SessionManagerTests` construct `SessionManager()` with no store and must pass untouched. **Applicable skill: `superpowers:test-driven-development`.**

## TDD Checklist

- [ ] **RED**: `SessionManagerTests` new cases —
  - with `FakeSecureCacheStore`: `update(accessToken: "a", refreshToken: "r")` then a **fresh** `SessionManager` over the same store exposes `accessToken == "a"`, `refreshToken == "r"`
  - `update(accessToken: "a2", refreshToken: nil)` keeps `refreshToken == "r"` (rotation semantics)
  - `update(accessToken: "a3", refreshToken: "r2")` → `refreshToken == "r2"`, old value gone from the store
  - `clear()` → both `accessToken` and `refreshToken` are `nil` and both store keys removed
  - without a store: behaviour identical to the existing cases
- [ ] **GREEN**: implement the optional-store read/write/reload/clear and rotation guard.
- [ ] **REFACTOR**: keep the `NSLock` discipline; ensure `@unchecked Sendable` justification comment still holds; no `async` added to the protocol.

## Definition of Done (DoD)

- `swift test --package-path Packages/Core` green, **including every pre-existing `SessionManagerTests` case unchanged**.
- Lint/format clean from repo root; `ArchTests` green.
- One commit: `[IOS_SUPER_APP_TEMPLATE] Core: SessionManager refresh token + optional Keychain persistence`.

## Dependencies & Blockers

- Blocks [Task 4](task_4_network_refresh_machinery.md), [Task 6](task_6_app_network_composition_wiring.md).
- Not blocked by [Task 1](task_1_core_token_refresher_seam.md) (independent files) but is normally implemented after it.

## References & Rollback

- Flutter `refresh_token.md` §4 (storage), §2 (rotation — "lưu đè Refresh Token mới").
- Rollback: revert the commit; `SessionManaging` returns to access-token-only. No other epic task has landed yet if this is reverted early.
