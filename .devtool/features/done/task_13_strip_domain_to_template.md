---
id: "task_13_strip_domain_to_template"
status: "done"
priority: "medium"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:23.415Z"
completedAt: "2026-09-03T03:30:23.415Z"
labels: ["template", "cleanup"]
order: "a1V"
---
# Task 13: Strip digital-wallet domain → 3-feature template

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

Produce the reusable template (Goal G8). On the epic worktree:

- **Delete feature modules**: `features/authentication`, `features/myWallet`, `features/transactions`, `features/trends`, `features/splash`. Remove each from `settings.gradle.kts`, `:app`/`:shell` build files, and any `AppRoutes` entry.
- **Delete `domain/`** entirely if only `authenticator` remained (it was folded into `:network` in Task 6) — remove the empty `:domain:*` includes.
- **Shell = 3 tabs**: `home` (stub page already in `:shell` from Task 10), `scanner` (empty feature module — regenerate clean from `mason make mvi_feature --name scanner --delivery on-demand` in Task 14, or keep the existing emptied module as a placeholder here and convert in Task 14), `settings` (the real feature, kept). Default tab = `settings` (last index) — matches the Flutter template.
- **Assets**: delete wallet-specific `app/src/main/res/**` drawables, any Lottie/JSON test fixtures, `screenshots/` wallet screenshots. Keep generic app-icon/theme resources.
- **Auth removal**: any `AuthNavigationInitializer`-equivalent in `:app`/`:shell` — remove, or leave a commented stub with a "re-enable when the project needs auth" note (mirrors the Flutter decision).
- Update `AndroidManifest`, string resources, `AppConfig` to drop wallet naming (final rename is Task 15; here just remove dead wallet strings/resources).

Konsist whitelist should now be trivially empty (the couplings lived in deleted features). Re-run the full gate.

## Relevant Files & Context Pointers

- `settings.gradle.kts` — remove 5 feature includes + any `:domain:*`
- `features/{authentication,myWallet,transactions,trends,splash}/**` — delete
- `app/build.gradle.kts`, `shell/build.gradle.kts` — drop `FEATURE_*` for removed features
- `platform/src/main/kotlin/com/danhdue/platform/AppRoutes.kt` — remove dead routes
- `app/src/main/res/**`, `app/src/main/assets/**`, `screenshots/**`
- `app/src/main/kotlin/com/danhdue/androiddigitalwallet/**` — auth initializer / DI for removed features
- `README.md`, `ARCHITECTURE.md`, `docs/**` — prune wallet-domain references (fuller pass in Task 15)
- Reference: `bloc_digital_wallet/.worktrees/flutter_super_app_template` `template_flutter` Task 1 "trim package inventory" + Task 2 "rebuild host shell"

## Design Rationale

Same keep/cut list as the Flutter template epic (`settings` real + `scanner` empty + `home` stub), so the two templates stay conceptually aligned. Deleting rather than gutting the feature modules keeps the template small and the module graph honest.

Applicable skill: `@quality_check` after.

## TDD Checklist

**TDD Adaptation** — deletion + config. Verifiable steps:

- [ ] Remove the 5 feature modules + `:domain:*`; strip build files, routes, DI, assets.
- [ ] `./gradlew assembleDebug` green with only `home`(stub)/`scanner`/`settings`.
- [ ] `./gradlew testDebugUnitTest` green (only `settings` + infra + shell tests remain).
- [ ] `./gradlew :konsist-test:test` green, whitelist empty.
- [ ] Launch: 3 tabs, `settings` default, no crash, no dead menu items.

## Definition of Done

- Only `home` stub / `scanner` / `settings` present as features.
- No `:domain:*` modules; no wallet-specific assets.
- Full gate (Konsist + guard + detekt/spotless) green; `assembleDebug` green; 3-tab app runs.

## Dependencies & Blockers

- Blocked by [Task 12](task_12_migrate_remaining_features.md).
- Blocks [Task 14](task_14_scanner_dynamic_feature.md), [Task 15](task_15_rename_script_and_docs.md).

## References & Rollback

- Source spec §8, §9 Phase 3.
- Rollback: this happens on the epic worktree only — `git checkout` the pre-strip commit; source `develop` is never touched.