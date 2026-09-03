---
id: "task_6_extract_network_module"
status: "done"
priority: "high"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:37.013Z"
completedAt: "2026-09-03T03:30:37.013Z"
labels: ["architecture", "refactor", "network"]
order: "a1a"
---
# Task 6: Extract `:network` (+ fold `domain/authenticator`)

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

`:network` (`com.danhdue.network`) owns the HTTP stack, depends only on `:core`. Move from `libraries/framework/src/main/java/com/danhdue/framework/`:

- `network/**` except the pure types already moved to `:core` in Task 5 — i.e. `ApiCallExtension`, `HandleError`, `NetworkHelper`, `environment/**` (`Environment`, `EnvironmentInterceptor`), `interceptor/**` (`GlobalHeaderInterceptor`, `HttpRequestInterceptor`), `model/FeatureConfig`, `moshi/EnumValueJsonAdapter`, `flipper/**` (`FlipperNetworkObject`, `FlipperNavigationObject`)
- `di/NetworkCoreModule.kt` (the Retrofit/OkHttp/Moshi Hilt module)
- `base/app/{NetworkConfig,FlipperInitializer}.kt`
- the `NetworkResponseAdapterFactory` wiring (the factory registration; the `NetworkResponse` type itself is in `:core`)

Fold **`domain/authenticator`** into `:network`: `TokenAuthenticator` (OkHttp `Authenticator` for 401 refresh) is a network concern. Move `domain/authenticator/**` → `network/authenticator/**`; delete the `:domain:authenticator` module from `settings.gradle.kts`. Also: the 401 interceptor here is where `AppEventBus.publish(UserLoggedOut)` will be wired (Task 11) — leave a `// TODO(task_11): publish UserLoggedOut` marker.

Add `NETWORK` dependency constant; `addNetworkDependencies()` extension now resolves to `project(":network")` + the transitive libs. `libraries/framework` temporarily depends on `:network`.

## Relevant Files & Context Pointers

- `libraries/framework/src/main/java/com/danhdue/framework/network/**`
- `libraries/framework/src/main/java/com/danhdue/framework/di/NetworkCoreModule.kt`
- `libraries/framework/src/main/java/com/danhdue/framework/base/app/{NetworkConfig,FlipperInitializer}.kt`
- `domain/authenticator/**`, `settings.gradle.kts` (remove `:domain:authenticator`)
- `buildSrc/src/main/kotlin/extensions/DependencyHandlerExtensions.kt` (`addNetworkDependencies`)
- `buildSrc/src/main/kotlin/Deps.kt` (`Modules` object)
- `docs/system-design/NETWORK_ARCHITECTURE_ANALYSIS.md`, `docs/DYNAMIC_HEADERS.md`, `docs/flipper_integration.md` — update paths after the move
- `features/authentication/src/main/java/com/danhdue/authentication/data/datasources/remote/TokenAuthenticator.kt` — confirm whether the feature has its own copy vs. `domain/authenticator`; reconcile

## Design Rationale

Mirrors Flutter `packages/network`. Folding `authenticator` in removes a one-class module and puts token-refresh next to the interceptors it cooperates with. Flipper network/nav objects move here because they are network-tooling, not app-shell.

Applicable skills: `@api_integration` (directly relevant — this is the network layer it documents); `@moshi_dto_generator` for any DTO touched; `@quality_check` after.

## TDD Checklist

**TDD Adaptation** — module extraction. Verifiable steps:

- [ ] `git mv` the packages; rename `package`/`import` (`...framework.network.*` → `...network.*`, `...domain.authenticator.*` → `...network.authenticator.*`).
- [ ] New `:network` build file (android-library + hilt, no compose), `implementation(project(":core"))`.
- [ ] Remove `:domain:authenticator` from `settings.gradle.kts`; delete the empty `domain/` dir if nothing else remains.
- [ ] Fix `libraries/framework` + `features/authentication` imports.
- [ ] Run existing network tests + `features/authentication` tests — no regression.
- [ ] `assembleDebug` green; smoke-test login + a 401 refresh path.

## Definition of Done

- `:network` builds standalone; depends only on `:core`.
- `:domain:authenticator` module gone; token refresh works.
- All existing tests pass; `assembleDebug` green; auth flow smoke-tested.
- Docs referencing old network paths updated.

## Dependencies & Blockers

- Blocked by [Task 5](task_5_extract_core_module.md).
- Blocks [Task 9](task_9_rewire_and_architecture_doc.md).

## References & Rollback

- Source spec §4.1.
- `docs/system-design/NETWORK_ARCHITECTURE_ANALYSIS.md`.
- Rollback: revert the PR; re-add `:domain:authenticator` to `settings.gradle.kts`.