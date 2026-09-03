---
id: "task_8_merge_ui_kit_module"
status: "done"
priority: "high"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:46.399Z"
completedAt: "2026-09-03T03:30:46.399Z"
labels: ["architecture", "refactor", "ui"]
order: "a1X"
---
# Task 8: Merge `components` + `jetframework` → `:ui_kit`

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

Mirror Flutter `packages/ui_kit` (Goal G2). Merge the two Compose-only support modules into one `:ui_kit` (`com.danhdue.ui_kit`), depending on `:core` (+ `:framework` only if a component needs `NestedNavigator`/CompositionLocals — prefer not):

- `libraries/components/**` — the reusable Compose component library (buttons, no-ripple impl, text-emphasis, etc.; see `docs/NO_RIPPLE_*`, `docs/TEXT_EMPHASIS_GUIDE.md`)
- `libraries/jetframework/src/main/java/com/danhdue/jetframework/permission/**` — the runtime-permission helpers

Pick one namespace (`com.danhdue.ui_kit`) and repackage both trees under it. Replace `COMPONENT` + `JET_FRAMEWORK` dependency constants with a single `UI_KIT`. `:app` and every feature currently listing both now list `UI_KIT`.

If `jetframework` has non-permission content, evaluate: permission helpers → `:ui_kit`; anything non-UI → `:core`.

## Relevant Files & Context Pointers

- `libraries/components/**`, `libraries/components/build.gradle.kts`
- `libraries/jetframework/**`, `libraries/jetframework/build.gradle.kts` (namespace `com.danhdue.jetframework`)
- `buildSrc/src/main/kotlin/Deps.kt`, `buildSrc/src/main/kotlin/extensions/` — `COMPONENT`, `JET_FRAMEWORK` → `UI_KIT`
- `app/build.gradle.kts` (lists `COMPONENT`, `JET_FRAMEWORK`), every `features/*/build.gradle.kts` (lists `COMPONENT`)
- `settings.gradle.kts`
- `docs/NO_RIPPLE_IMPLEMENTATION.md`, `docs/NO_RIPPLE_SUMMARY.md`, `docs/TEXT_EMPHASIS_GUIDE.md` — update package paths
- `screenshots/unit_tests/` — component screenshot tests, if any, must keep passing

## Design Rationale

`components` and `jetframework` are both "Compose things features reuse" at the same layer — one module is simpler and matches the Flutter package set exactly. Keeping `:ui_kit` off `:framework` where possible preserves a clean `core ← {framework, network, ui_kit, platform}` fan-out.

Applicable skill: `@quality_check` after. (If component visuals change, `mobile-uiux-promax` would apply — but this is a move, not a redesign.)

## TDD Checklist

**TDD Adaptation** — module merge. Verifiable steps:

- [ ] `git mv` both trees under `ui_kit/src/main/kotlin/com/danhdue/ui_kit/`; rename `package`/`import`.
- [ ] New `:ui_kit` build file (android-library + compose), `implementation(project(":core"))`.
- [ ] Swap `COMPONENT`/`JET_FRAMEWORK` → `UI_KIT` in `:app` + all features.
- [ ] Delete `:libraries:components` + `:libraries:jetframework` from `settings.gradle.kts`.
- [ ] Run existing component/permission tests + all feature tests; run screenshot tests — no regression.
- [ ] `assembleDebug` green; visual smoke of a screen using both a component and a permission prompt.

## Definition of Done

- `:ui_kit` builds standalone; single namespace.
- `components` + `jetframework` modules removed.
- All existing tests + screenshot tests pass; `assembleDebug` green.

## Dependencies & Blockers

- Blocked by [Task 5](task_5_extract_core_module.md).
- Blocks [Task 9](task_9_rewire_and_architecture_doc.md).

## References & Rollback

- Source spec §4.1.
- Rollback: revert the PR; re-add both modules to `settings.gradle.kts`.