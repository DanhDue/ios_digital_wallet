---
id: "task_4_ios_core_package"
status: "todo"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: null
labels: ["architecture", "spm", "core"]
order: "a4"
---

# Task 4: Create `Core` SPM package

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: A (behavioral).** Full dual-persona flow: `### BDD Scenarios` → `### TDD Tests` → RED → GREEN (Source Spec §9A). Target: Swift / XCTest.

## Requirement Analysis

`Packages/Core/` — the dependency floor. stdlib only, no other package, no UI framework. Mirror of Flutter `packages/core` / Android `:infra:core`.

Contents (all `public`):

| Type | File | Notes |
|---|---|---|
| `enum DataState<T>` | `Sources/Core/DataState.swift` | `.success(T)` / `.error(AppError)` / `.loading`; `map`, `flatMap` |
| `struct AppError: Error, Equatable` | `AppError.swift` | `code`, `message`, `underlying: String?` |
| `protocol Logger` | `Logging/Logger.swift` | `debug/info/error(_:file:function:line:)` |
| `enum SafeExecution` | `SafeExecution.swift` | `run(logger:label:fallback:_:)` — catch → log → fallback |
| `actor ReplayQueue<T: Codable>` | `ReplayQueue.swift` | `enqueue`, `dequeueAll` (drains) |
| `protocol CacheStore` + `UserDefaultsCacheStore` | `Cache/CacheStore.swift` | `get(_:key:)` / `set(_:key:)` / `remove` / `clearAll` |
| `protocol SecureCacheStore: CacheStore` + `KeychainCacheStore` | `Cache/SecureCacheStore.swift` | Keychain-backed |
| `protocol SessionManaging` + `SessionManager` | `Session/SessionManager.swift` | `accessToken`, `update(accessToken:)`, `clear()` |
| `protocol AuthEventSink` | `Auth/AuthEventSink.swift` | `onUnauthorized()` — inversion seam for Network 401 |
| extensions | `Extensions/` | `Result+`, `Optional+`, `Collection+` helpers actually used elsewhere |

`Package.swift`: `Core` library + `CoreTests` test target, platforms `.iOS(.v16)`.

## Relevant Files & Context Pointers

- `Packages/Core/Package.swift`, `Packages/Core/Sources/Core/**`, `Packages/Core/Tests/CoreTests/**` — **NEW**
- `Tuist/Package.swift` — add `.package(path: "Packages/Core")` inside `// tuist:packages:begin/end`
- `Project.swift` — app target depends on `Core` (temporary, to keep it compiling)
- Source Spec §7 (full Core API), §4.2 (module map), Changelog #8 (`AuthEventSink`)

## Design Rationale

`ReplayQueue` is an `actor` for data-race safety (closest to Kotlin's thread-safe queue). `SessionManager` is a `class` conforming to `SessionManaging` — reads dominate writes and the UI layer serialises on `@MainActor`. `SecureCacheStore` (Keychain) lives here, not a separate package — it's a storage primitive, matching Android's `:core`. `AuthEventSink` is a bare protocol so `Network` can signal 401 without importing `Platform`.

**Applicable skills:** none specific; check `.agents/skills/` for a storage/keychain skill if one exists.

### BDD Scenarios

```gherkin
# Happy path
Scenario: DataState carries a success value
  Given a DataState<Int>.success(42)
  When I map { $0 * 2 }
  Then the result is .success(84)

Scenario: SafeExecution returns the block value when it does not throw
  Given a block that returns "ok"
  When SafeExecution.run(fallback: "fb") { block }
  Then it returns "ok" and the logger is not called

# Boundary / equivalence partitioning
Scenario Outline: CacheStore round-trips Codable values
  Given key "<key>" and value <value>
  When I set then get
  Then get returns an equal value
  Examples: | key | value |  (empty string key, 1-char key, 512-char key, Int.min, Int.max, [], nested struct)

Scenario: CacheStore.get returns nil for a missing key
Scenario: CacheStore decode failure (stored bytes are not the requested type) returns nil and logs
Scenario: KeychainCacheStore.set on a simulator with Keychain available round-trips
Scenario: KeychainCacheStore.get when the item is absent returns nil (no throw)

# State transitions
Scenario: SessionManager.update(accessToken:) then clear() leaves accessToken nil
Scenario: SessionManager.clear() when already empty is a no-op

# Async / race
Scenario: ReplayQueue concurrent enqueue from 100 tasks then dequeueAll returns 100 items
Scenario: dequeueAll drains — a second dequeueAll returns []
Scenario: enqueue interleaved with dequeueAll never loses or duplicates an item

# Failure injection
Scenario: SafeExecution block throws -> returns fallback, logger.error called once with the label
Scenario: CacheStore.set with a value whose Codable encode throws -> no crash, logs, key stays unset

# Emission order — n/a for Core (no @Published); assert Result ordering in ReplayQueue instead
Scenario: ReplayQueue preserves FIFO order for sequential enqueue

# Resource teardown
Scenario: ReplayQueue holds no reference after dequeueAll (items array is empty)
```

### TDD Tests

- `DataStateTests` — map/flatMap on each case; identity; error propagation.
- `SafeExecutionTests` — success path (no log), throw path (fallback + one `error` log with label), fallback type identity.
- `ReplayQueueTests` — FIFO; `await withTaskGroup` 100 concurrent `enqueue` → count 100; drain semantics; interleave enqueue/dequeue with `Task.yield()`.
- `UserDefaultsCacheStoreTests` — parameterised round-trip (the Examples table); missing key → nil; corrupted bytes → nil + log (inject a spy `Logger`).
- `KeychainCacheStoreTests` — round-trip on simulator; absent item → nil; `clearAll` wipes.
- `SessionManagerTests` — update→clear transitions; idempotent clear.
- All async tests use `async`/`await`; spy `Logger` records calls for assertion.

### RED → GREEN

- RED: write every test above against empty stubs; confirm they fail (compile-fail counts as RED for missing types — implement signatures first, bodies `fatalError()`).
- GREEN: implement each type minimally to pass. No extra API beyond §7.

## Definition of Done

- `swift test --package-path Packages/Core` green; every BDD scenario has a passing test.
- Coverage ≥ 80% (floor) for `DataState`, `SafeExecution`, `ReplayQueue`, both `CacheStore` impls.
- SwiftLint `--strict` + SwiftFormat `--lint` clean on `Packages/Core/`.
- `Core` wired into `Tuist/Package.swift` marker region; `tuist generate && xcodebuild build` green.
- No dependency on any other package (checked: `Package.swift` deps == []).

## Dependencies & Blockers

- Blocked by [Task 3](task_3_ios_archtests_ci_docs.md) (CI + ArchTests skeleton must be green).
- Blocks [Task 5](task_5_ios_framework_package.md), [Task 6](task_6_ios_network_package.md), [Task 7](task_7_ios_appuikit_package.md), [Task 8](task_8_ios_platform_package.md).

## References & Rollback

- Source Spec §7, §4.2.
- Rollback: remove `Packages/Core/` and its marker-region line in `Tuist/Package.swift`; drop the app-target dep. Skeleton reverts.
