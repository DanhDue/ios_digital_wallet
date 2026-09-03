---
id: "task_2_konsist_gate"
status: "done"
priority: "high"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:04.897Z"
completedAt: "2026-09-03T03:30:04.897Z"
labels: ["architecture", "ci", "governance"]
order: "a2"
---
# Task 2: `:konsist-test` gate + Gradle feature guard

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

Enforcement by structure (Goal G6). Two complementary layers:

1. **`:konsist-test`** — a JVM/JUnit module (never shipped in the APK) using `com.lemonappdev:konsist`. It scans the whole `Kotlin` scope and asserts architecture rules as tests. Rules (see source spec §6.1):
   - **K1** cross-feature import: a file in `com.danhdue.<featureX>` must not import `com.danhdue.<featureY>` — unless the pair `X→Y` is a line in `konsist_boundary_whitelist.txt`.
   - **K2** layer: `..presentation..` must not import `..data..`; `..domain..` must not import `..presentation..`/`..data..`.
   - **K3** pure domain: `..domain..` must not import `android.*` / `androidx.*`.
   - **K4** export discipline: top-level declarations under `..<feature>..data..` must not be `public`/`open` (default `internal`).
   - **K5** naming: `*ViewModel` extends `MviViewModel`; `*UseCase`; the `*Action`/`*State`/`*Event` set; `*Screen` is `@Composable`; `*Repository` (interface, in domain) / `*RepositoryImpl` (in data); `*Route : NavKey`; `*NavigationModule` is a Hilt `@Module` providing `@IntoSet EntryProviderInstaller`.
   - **K6** host privilege: only `:app`/`:shell` may depend on more than one `com.danhdue.features.*`.
   - **K7** core is the floor: `:core` must not import `com.danhdue.{framework,network,ui_kit,platform,features,shell}`.
   - **K8** feature must not import `com.danhdue.androiddigitalwallet.*` — except a module listed in `:app`'s `android.dynamicFeatures` (read that list, don't hand-whitelist).
   - **K9** a `*Route : NavKey` used outside its own feature must be declared in `:platform`, not in `..features..`.
2. **Gradle guard** in `commons.android-feature` — in an `afterEvaluate`, if the module's `implementation` config contains a `ProjectDependency` whose path starts `:features:` and is not this module, throw `GradleException`. This fails at sync, before Konsist runs. **This task ships it in *warn* mode** (log, don't throw); Task 11 flips it to fail.

Seed `konsist_boundary_whitelist.txt` with every current cross-feature edge: `home→myWallet`, `home→transactions`, `home→scanner`, `home→trends`, `home→settings` (from `features/home/build.gradle.kts`). Enable **only K5/K8** now (structurally safe on the current tree); K1/K6/K9 run in report-only, K2/K3/K4/K7 are deferred to Tasks 9/11 with a Konsist baseline file for any pre-existing violation.

## Relevant Files & Context Pointers

- `settings.gradle.kts` — add `include(":konsist-test")`
- `buildSrc/src/main/kotlin/Versions.kt`, `Deps.kt` — add `konsist` version + dep
- `buildSrc/src/main/kotlin/commons/android-feature.gradle.kts` — add the warn-mode guard block
- `features/home/build.gradle.kts` — source of the whitelist seed
- NEW: `konsist-test/build.gradle.kts`, `konsist-test/src/test/kotlin/com/danhdue/konsist/{BoundaryRules,LayerRules,NamingRules,HostRules}Test.kt`
- NEW: `scripts/konsist_boundary_whitelist.txt`
- Reference: `bloc_digital_wallet/.worktrees/flutter_super_app_template/scripts/check_module_boundaries.sh` + `module_boundary_whitelist.txt` (the bash equivalent this replaces)

## Design Rationale

Konsist reads the Kotlin AST, so it catches aliased/transitive imports a regex `grep` misses — the reason to use it over porting the Flutter bash script. The whitelist file format (`X→Y`, one per line, `#` comments) is copied verbatim from the Flutter gate so the two repos' mental model matches. Warn-mode-first lets Phase 0 land with zero behavior/PR-flow change.

Applicable skill: `@quality_check` after implementation.

## TDD Checklist

- [ ] **RED**: add a throwaway `com.danhdue.settings` file importing `com.danhdue.trends` → the K1 test fails; add its pair to the whitelist → passes; remove the file.
- [ ] **RED**: a mis-named `FooVm` → K5 fails.
- [ ] **GREEN**: implement each rule test; add the baseline file for legacy violations so the suite is green on the current tree.
- [ ] **REFACTOR**: factor shared scope helpers; document each rule with a KDoc pointing at the spec section.

## Definition of Done

- `./gradlew :konsist-test:test` green on the current repo structure.
- Whitelist seeded with the 5 `home→*` edges.
- Gradle guard present in `commons.android-feature`, warn-mode, logs on `features/home`.
- No change to any feature's runtime behavior; `assembleDebug` green.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_platform_module.md) (needs `:platform` types referenced by K9).
- Blocks [Task 3](task_3_github_actions_ci.md), [Task 9](task_9_rewire_and_architecture_doc.md), [Task 11](task_11_platform_routes_settings_pilot.md).

## References & Rollback

- Source spec §6.1, §6.2.
- Konsist docs: https://docs.konsist.lemonappdev.com/
- Rollback: remove `:konsist-test` from `settings.gradle.kts` and the guard block; the tree is otherwise untouched.