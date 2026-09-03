---
id: "task_4_mason_brick_wiring"
status: "done"
priority: "medium"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:08.197Z"
completedAt: "2026-09-03T03:30:08.197Z"
labels: ["tooling", "mason"]
order: "a4"
---
# Task 4: Update Mason bricks for the new wiring

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

New feature = one Mason command (Goal G7). Update the existing bricks so a generated feature is auto-wired the new way and never touches another feature.

`mvi_feature` hook (`post_gen`) must:
- (a) add `include(":features:{{name}}")` to `settings.gradle.kts`
- (b) generate `{{Name}}Route : NavKey` (feature-private by default; a prompt "used cross-feature?" → also append it to `:platform`'s `AppRoutes`)
- (c) generate `{{Name}}NavigationModule` — Hilt `@Module @InstallIn(SingletonComponent::class)` with `@Provides @IntoSet` returning an `EntryProviderInstaller` that registers `{{Name}}Screen` for `{{Name}}Route`
- (d) add a new `delivery` var (`install-time` default | `on-demand`):
  - `install-time`: add `implementation(project(":features:{{name}}"))` to `:app` **and** `:shell` build files — Hilt multibinding does the rest
  - `on-demand`: apply `com.android.dynamic-feature`; add `":features:{{name}}"` to `:app`'s `android.dynamicFeatures`; feature gets `implementation(project(":app"))`; force `{{Name}}Route` into `:platform`; generate `{{Name}}FeatureEntry : FeatureEntry` + `src/main/resources/META-INF/services/com.danhdue.platform.FeatureEntry`; add `<dist:module dist:onDemand="true">` to the feature manifest; add a `FeatureInstaller.ensureInstalled("{{name}}")` branch stub in `:shell`

`mvi_subfeature` hook: only adjust the package path to `com/danhdue/{{name}}` matching the current structure — no wiring change.

`remove_feature` / `remove_subfeature`: update to unwind every wire point above, including the `dynamicFeatures` branch.

**Keep the legacy bricks** — do not delete `mvi_feature`/`mvi_subfeature`/`remove_feature`/`remove_subfeature`; this task edits their hooks in place.

At Phase 0 the `:shell` module does not exist yet — write the hook so the `:shell` edits are conditional on the module being present (they take effect from Phase 2).

## Relevant Files & Context Pointers

- `bricks/mvi_feature/{brick.yaml,hooks/post_gen.dart,__brick__/}`
- `bricks/mvi_subfeature/{brick.yaml,hooks/post_gen.dart,__brick__/}`
- `bricks/remove_feature/`, `bricks/remove_subfeature/`
- `mason.yaml`, `mason-lock.json`
- `settings.gradle.kts`, `app/build.gradle.kts` — insertion targets
- `features/settings/build.gradle.kts` — the reference wiring a generated `install-time` feature should match
- `docs/MASON_GUIDE.md` — update after the hook changes
- Reference: `bloc_digital_wallet/.worktrees/flutter_super_app_template/bricks/pac_mvi_feature/hooks/post_gen.dart`

## Design Rationale

One `mvi_feature` brick with a `delivery` flag (not a separate DFM brick) keeps a single source of truth — the Flutter epic's "one parameterised brick beats 4 drifting bricks" decision, applied to Android. Wiring through Hilt `@IntoSet` (not a hand-edited registry) means the hook never has to parse and re-emit an aggregation list.

Applicable skill: none; run `@quality_check` after.

## TDD Checklist

**TDD Adaptation** — brick templates + a Dart hook. Verifiable steps:

- [ ] `mason make mvi_feature --name demo` on a scratch worktree → module compiles, appears in `settings.gradle.kts`, `demo` tab reachable, no edit to any other feature's files (`git diff --stat` shows only `:app`, `:shell`, `settings.gradle.kts`, `features/demo/**`, `platform/**` if cross-feature).
- [ ] `mason make mvi_feature --name demo2 --delivery on-demand` → `com.android.dynamic-feature` applied, `dynamicFeatures` updated, `META-INF/services` file present, `assembleDebug` + `bundleDebug` green.
- [ ] `mason make remove_feature --name demo` → all wire points removed, `assembleDebug` green.
- [ ] Existing bricks still listed in `mason.yaml`; `mason get` clean.

## Definition of Done

- Both generation modes produce a buildable module wired only to host + `:platform`.
- `remove_feature` fully reverses either mode.
- `docs/MASON_GUIDE.md` updated with the `delivery` flag.
- Legacy bricks retained and still runnable.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_platform_module.md) (hook references `:platform`/`AppRoutes`).
- Related: [Task 14](task_14_scanner_dynamic_feature.md) finalises the on-demand path against a real feature.

## References & Rollback

- Source spec §7.
- Rollback: `git checkout bricks/` — hooks are self-contained.