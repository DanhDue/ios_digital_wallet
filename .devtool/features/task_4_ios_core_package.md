---
id: "task_4_ios_core_package"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["architecture", "spm", "core"]
order: "a4"
---

# Task 4: Create `Core` SPM local package

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Create `Sources/Core/` as an SPM local package — the mandatory foundation that every other module depends on. Mirror of Flutter `packages/core` and Android `:core`.

**Contents** (all `public`, no UI framework dependency):

| Type | File | Equivalent |
|---|---|---|
| `enum DataState<T>` | `DataState.swift` | Flutter `Either<Failure,T>` / Android `DataState<T>` |
| `struct AppError: Error` | `AppError.swift` | Flutter `Failure` / Android custom exceptions |
| `protocol Logger` | `Logger.swift` | Android `Logger` contract in `:core` |
| `struct SafeExecution` | `SafeExecution.swift` | Android `core.SafeExecution` |
| `actor ReplayQueue<T: Codable>` | `ReplayQueue.swift` | Android `core.ReplayQueue` (from `logger_native_bridge` generalized) |
| `protocol CacheStore` + `UserDefaultsCacheStore` | `Cache/CacheStore.swift` | Android `pref/CacheStore` |
| `protocol SecureCacheStore` + Keychain impl | `Cache/SecureCacheStore.swift` | Android `pref/SecureCacheStore` |
| `class SessionManager` | `Session/SessionManager.swift` | Android `SessionManager` in `:core` |
| Swift extensions | `Extensions/` | Android `extension/` in `:core` |

`Package.swift` targets: `Core` (lib) + `CoreTests` (test). No external dependencies — stdlib only.

Add `Sources/Core` to `iOSDigitalWallet.xcodeproj` as a local SPM package reference so the app target can import it.

## Relevant Files & Context Pointers

- `Sources/Core/Package.swift` — **NEW**
- `Sources/Core/Sources/Core/*.swift` — **NEW** (all files above)
- `Sources/Core/Tests/CoreTests/*.swift` — **NEW** unit tests
- `iOSDigitalWallet.xcodeproj` — add local package reference + link `Core` to app target
- Reference: `bloc_digital_wallet/packages/core/lib/` (Flutter — structural mirror)
- Reference: `.devtool/epic/android_super_app_template/2026-09-02-android-super-app-template-design.md` §4.1 `:core` content list
- Source spec §7 (Core module detail)

## Design Rationale

`ReplayQueue` uses Swift `actor` for thread safety — the closest Swift equivalent to Kotlin's thread-safe queue. `SafeExecution` is a static helper struct (no instantiation) matching the Android static method pattern. `SessionManager` is a class (reference type, shared state) — not an actor, because reads are more frequent than writes and Combine's `@Published` naturally serializes on `MainActor` at the UI layer.

`SecureCacheStore` backed by Keychain is included here (not in a separate package) because it's a storage primitive, not a feature — same as Android's `AeadManager` / `SecureCacheStore` in `:core`.

## TDD Checklist

- [ ] **RED**: Write `DataStateTests` — `DataState.success` wraps value correctly; `DataState.error` wraps `AppError`; map/flatMap if added.
- [ ] **RED**: Write `SafeExecutionTests` — `run` returns fallback when block throws; returns value when block succeeds; logger called on error.
- [ ] **RED**: Write `ReplayQueueTests` — `enqueue` + `dequeueAll` returns items in order; `dequeueAll` empties queue; concurrent enqueue is safe (`async let`).
- [ ] **RED**: Write `UserDefaultsCacheStoreTests` — `set`/`get` round-trip for `String`, `Int`, `Codable` struct; `remove` clears key; `clearAll` wipes all.
- [ ] **GREEN**: Implement all types to pass tests.
- [ ] **REFACTOR**: Add KDoc-style comments to all `public` API. Run SwiftLint + SwiftFormat — clean. Confirm `swift test` in `Sources/Core/` passes.

## Definition of Done

- `Sources/Core/` builds as SPM local package (`swift build` in `Sources/Core/` succeeds).
- All unit tests green (`swift test`).
- App target imports `Core` without error (`xcodebuild build` green).
- SwiftLint + SwiftFormat clean (no violations in `Sources/Core/`).
- Coverage ≥ 80% for `DataState`, `SafeExecution`, `ReplayQueue`, `CacheStore` impl.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_ios_quality_tooling.md) (SwiftLint must be configured to run on new files).
- Blocked by [Task 2](task_2_ios_boundary_ci.md) (CI must be green before adding packages).
- Blocks [Task 5](task_5_ios_framework_package.md), [Task 6](task_6_ios_network_package.md), [Task 7](task_7_ios_appuikit_package.md), [Task 8](task_8_ios_platform_package.md) (all depend on `Core`).

## References & Rollback

- Source spec §7 (Core module detail).
- Rollback: remove `Sources/Core/` directory + remove local package reference from `iOSDigitalWallet.xcodeproj`. App reverts to Hello World.
