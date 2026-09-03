---
id: "task_7_extract_framework_module"
status: "done"
priority: "high"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:42.291Z"
completedAt: "2026-09-03T03:30:42.291Z"
labels: ["architecture", "refactor", "navigation"]
order: "a6"
---
# Task 7: Extract `:framework` (MVI + navigation3 mechanism)

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

`:framework` (`com.danhdue.framework`) is the UI/state base — depends on `:core` only. After Tasks 5–6, `libraries/framework` should be left holding exactly:

- `base/mvi/{MviViewModel,BaseViewState}.kt`, `base/mvvm/MvvmViewModel.kt`
- `navigation/{Navigator,NestedNavigator,EntryProviderInstaller,FlipperBackstackObserver}.kt` — **the host navigation mechanism, kept verbatim.** `CommonRoutes.kt` already left for `:platform` in Task 1.
- `base/app/{CoreApplication,AppLifecycleCallback,MultiDexInitializer,TimberInitializer,FirebaseCrashlyticsReportTree}.kt` — decide per-file: app-lifecycle plumbing stays in `:framework`; anything purely `:core`-shaped (a crash tree that only needs the `Logger` contract) can move down.
- `di/` leftovers not already in `:core`/`:network`
- `platform/MobileService.kt` — Google/Huawei mobile-services detection; `:framework` (needs `Context`, no feature knowledge)

Rename the module: `libraries/framework` → `:framework` (drop the `libraries/` path segment; `settings.gradle.kts` `include(":framework")`, `projectDir` if needed). Keep namespace `com.danhdue.framework`. `FRAMEWORK` dependency constant now points at `:framework`.

`:framework` **must not** gain a Compose *feature* dependency, but it does use Compose runtime for `staticCompositionLocalOf` (the `LocalEntryProviderInstallers` / `LocalNestedNavigator` CompositionLocals) and `navigation3` — apply `commons.android-compose` here. That's fine: `:framework` is the "has UI/state" tier (source spec §3 principle 4).

## Relevant Files & Context Pointers

- `libraries/framework/src/main/java/com/danhdue/framework/{base/mvi,base/mvvm,navigation,platform}/**`
- `libraries/framework/src/main/java/com/danhdue/framework/base/app/**` — partition
- `libraries/framework/build.gradle.kts`
- `libraries/framework/src/main/java/com/danhdue/framework/navigation/{Navigator,NestedNavigator,EntryProviderInstaller,FlipperBackstackObserver}.kt` — **do not modify logic**
- `settings.gradle.kts`, `buildSrc/src/main/kotlin/Deps.kt` (`Modules.FRAMEWORK`)
- `buildSrc/src/main/kotlin/commons/{android-library,android-compose,dagger-hilt}.gradle.kts`
- `ARCHITECTURE.md` (root) — the MVI contract this module implements
- `docs/MVI_ANALYSIS.md`

## Design Rationale

The navigation3 mechanism (`Navigator` `@ActivityRetainedScoped` backstack, `NestedNavigator` per-tab nested backstacks, `EntryProviderInstaller` Hilt-multibound into `NavDisplay`) is the decoupled cross-module nav the epic keeps — **not replaced** (source spec §5, §11; explicit user instruction). This task only relocates it into a focused module. `MviViewModel` is `:framework` because it depends on `:core` primitives but is the base every feature ViewModel extends (Konsist K5).

Applicable skill: `@quality_check` after.

## TDD Checklist

**TDD Adaptation** — extraction of already-tested code. Verifiable steps:

- [ ] `git mv` remaining packages; the module directory moves from `libraries/framework/` to `framework/`.
- [ ] Build file: android-library + compose + hilt, `implementation(project(":core"))`; drop network/room deps now owned elsewhere.
- [ ] Fix imports across every consumer that referenced `com.danhdue.framework.network.*` / `.pref.*` etc. (those now come from `:core`/`:network`) — mechanical.
- [ ] Run `libraries/framework` existing tests (MVI base tests) + all feature `testDebugUnitTest` — no regression.
- [ ] `assembleDebug` green; manual smoke: tab switching, nested back navigation inside a tab, deep back-stack pop.

## Definition of Done

- `:framework` builds standalone, depends only on `:core`.
- `Navigator`/`NestedNavigator`/`EntryProviderInstaller` byte-for-byte unchanged in logic.
- Nested navigation verified working by manual smoke test.
- All existing tests pass; `assembleDebug` green.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_platform_module.md) (`CommonRoutes` already relocated), [Task 5](task_5_extract_core_module.md), [Task 6](task_6_extract_network_module.md).
- Blocks [Task 9](task_9_rewire_and_architecture_doc.md), [Task 10](task_10_extract_shell_thin_app.md).

## References & Rollback

- Source spec §4.1, §5.
- Rollback: revert the PR; module returns to `libraries/framework` owning everything.