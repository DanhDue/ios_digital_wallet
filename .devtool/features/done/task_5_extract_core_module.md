---
id: "task_5_extract_core_module"
status: "done"
priority: "high"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:34.870Z"
completedAt: "2026-09-03T03:30:34.870Z"
labels: ["architecture", "refactor"]
order: "a1b"
---
# Task 5: Extract `:core`

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

Split the god-module `libraries/framework` (Goal G2). `:core` is the mandatory floor for every module — **no Compose, no feature knowledge**. Move these packages out of `libraries/framework/src/main/java/com/danhdue/framework/` into a new `:core` module (`com.danhdue.core`):

- `network/DataState.kt`, `network/calladapter/**` (the `NetworkResponse` type + adapter — the `Result`/`DataState` primitives), `network/HttpStatusCode.kt` — the pure result/status types (the Retrofit/OkHttp *wiring* stays for Task 6)
- `coroutines/DispatcherProvider.kt`
- `extension/**` (Any/Coroutine/Device/Flow/Internet/Moshi/String/Toast/Variable/View/Intent)
- `pref/**` (`CacheStore`, `SecureCacheStore`, `AeadManager`)
- `room/**` (`BaseDao`, converters) — plus the Room runtime deps
- `session/SessionManager.kt`
- `usecase/**` (`DataStateUseCase`, `LocalUseCase`, `ReturnUseCase`, `FlowPagingUseCase`)
- `utils/**` (`AppCoroutineScope`, `CrashReportingTree`, `FakeCrashLibrary`, `NetworkDetection`, `NetworkStatus`)
- a `Logger` contract (currently Timber usage is scattered — define the interface here; keep the Timber impl wiring in `:core` or `:app` as-is)
- `base/app/AppInitializer.kt` + `AppInitializerImpl.kt` (the `androidx.startup`-style init contract) — but **not** `FlipperInitializer`/`NetworkConfig` (those are network, Task 6)

Decide per-file when unsure by the rule: **does it need Compose or a feature type? If no → `:core`.** Room + prefs go here (matches the Flutter `packages/core` which also owns storage — source spec §11).

Create `:core` with a new `commons.android-library`-only convention (Hilt allowed, **no** Compose plugin). Add `CORE` dependency constant. `libraries/framework` temporarily depends on `:core` so nothing else breaks yet (full rewire is Task 9).

## Relevant Files & Context Pointers

- `libraries/framework/src/main/java/com/danhdue/framework/{coroutines,extension,pref,room,session,usecase,utils}/**`
- `libraries/framework/src/main/java/com/danhdue/framework/network/{DataState.kt,HttpStatusCode.kt,calladapter/**}`
- `libraries/framework/src/main/java/com/danhdue/framework/base/app/{AppInitializer,AppInitializerImpl}.kt`
- `libraries/framework/build.gradle.kts` — dependency list to partition
- `buildSrc/src/main/kotlin/commons/{android-library,dagger-hilt}.gradle.kts`
- `buildSrc/src/main/kotlin/Deps.kt`, `extensions/DependencyHandlerExtensions.kt` (`addStorageDependencies`, `addCommonDependencies`)
- `settings.gradle.kts`

## Design Rationale

`:core` mirrors Flutter `packages/core`: the base every module builds on. Keeping it Compose-free is what lets non-UI modules (e.g. a future headless worker) and `:konsist-test`'s K7 rule stay meaningful. Moving in whole packages (not cherry-picking files) keeps the diff mechanical and reviewable.

Applicable skills: `@moshi_dto_generator` is unrelated here; `@quality_check` after. `@api_integration` context is relevant background for the `NetworkResponse` types being moved.

## TDD Checklist

**TDD Adaptation** — pure module extraction, no new behavior. Verifiable steps:

- [ ] Move the packages via `git mv`; update `package`/`import` statements (`com.danhdue.framework.*` → `com.danhdue.core.*` for moved files).
- [ ] Create `:core` build file (android-library + hilt, no compose).
- [ ] Point `libraries/framework` at `:core`; fix its now-broken imports.
- [ ] Run the **existing** test suites (`libraries/framework`, `libraries/testutils`, every feature's `testDebugUnitTest`) — confirm no regression.
- [ ] `./gradlew assembleDebug` green; launch the app, smoke-test navigation + a network call.

## Definition of Done

- `:core` builds standalone (`./gradlew :core:assembleDebug`), has no `androidx.compose` dependency.
- Existing tests all still pass; no test deleted.
- `assembleDebug` green; app runs identically.

## Dependencies & Blockers

- Independent of Phase 0 tasks, but sequence after [Task 2](task_2_konsist_gate.md) so K7 can be switched on in [Task 9](task_9_rewire_and_architecture_doc.md).
- Blocks [Task 6](task_6_extract_network_module.md), [Task 7](task_7_extract_framework_module.md), [Task 8](task_8_merge_ui_kit_module.md), [Task 9](task_9_rewire_and_architecture_doc.md).

## References & Rollback

- Source spec §4.1.
- Rollback: revert the extraction PR — `libraries/framework` returns to owning these packages.