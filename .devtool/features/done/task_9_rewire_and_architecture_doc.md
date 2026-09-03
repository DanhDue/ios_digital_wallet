---
id: "task_9_rewire_and_architecture_doc"
status: "done"
priority: "high"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:48.274Z"
completedAt: "2026-09-03T03:30:48.274Z"
labels: ["architecture", "refactor", "docs"]
order: "a1W"
---
# Task 9: Rewire consumers + enable Konsist layer rules + Android `ARCHITECTURE.md`

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

Close out Phase 1:

1. **Rewire every consumer** to the new module set. After Tasks 5–8, `libraries/framework` is empty — delete it. Every `features/*/build.gradle.kts` and `app/build.gradle.kts`:
   - `FRAMEWORK` → keep (now `:framework`), add `CORE`, `NETWORK` (features that do IO), `UI_KIT`, `PLATFORM`
   - remove `COMPONENT` / `JET_FRAMEWORK`
   - `addNetworkDependencies()` / `addStorageDependencies()` now resolve through `:network` / `:core`
   - fix any remaining `import com.danhdue.framework.{network,pref,room,session,utils,coroutines,extension}.*` → `com.danhdue.{core,network}.*` (mechanical, repo-wide)
2. **Enable Konsist K2 + K7** (layer rules + core-is-floor) as *failing* tests. Add a Konsist baseline entry for any pre-existing violation found (e.g. a `domain` file importing `androidx.*`) with a `// TODO` to clean it — do not fix unrelated legacy debt here.
3. **Write `docs/architecture/ARCHITECTURE.md`** (Android edition) — same table-of-contents structure as `bloc_digital_wallet/.worktrees/flutter_super_app_template/docs/architecture/ARCHITECTURE.md`, terms mapped: Widget→Composable, BLoC→`MviViewModel`, `Either<Failure,T>`→`NetworkResponse`/`DataState`, `context.t`→string resources, `mason make pac_mvi_feature`→`mason make mvi_feature`. Include the module map + dependency graph from the HLD.

## Relevant Files & Context Pointers

- `app/build.gradle.kts`, every `features/*/build.gradle.kts` (8 modules)
- `buildSrc/src/main/kotlin/extensions/DependencyHandlerExtensions.kt`, `Deps.kt` (`Modules`)
- `settings.gradle.kts` — remove `:libraries:framework`, `:libraries:components`, `:libraries:jetframework`, `:domain:authenticator`
- `konsist-test/src/test/kotlin/com/danhdue/konsist/LayerRulesTest.kt` — flip K2/K7 to enforced
- `scripts/konsist_baseline.txt` (or Konsist's native baseline mechanism)
- NEW: `docs/architecture/ARCHITECTURE.md`
- `ARCHITECTURE.md` (root, current) + `PROJECT_RULES.md` + `AGENTS.md` — cross-link / update the module list
- Reference: `bloc_digital_wallet/.worktrees/flutter_super_app_template/docs/architecture/ARCHITECTURE.md`

## Design Rationale

Doing all consumer rewiring in one task (rather than trickling through Tasks 5–8) keeps each extraction task's diff small and keeps a single "the tree now compiles against the new modules" checkpoint. The Android `ARCHITECTURE.md` is written *now*, while the module boundaries are fresh, so it is accurate from day one and can be referenced by every later task.

Applicable skill: `elements-of-style` / writing-clearly for the doc if available; `@quality_check` after.

## TDD Checklist

**TDD Adaptation** — mass rewire + doc. Verifiable steps:

- [ ] Update all build files + imports; delete the emptied modules from `settings.gradle.kts`.
- [ ] `./gradlew assembleDebug testDebugUnitTest` — full green, no test deleted.
- [ ] Flip K2/K7 to enforced; `./gradlew :konsist-test:test` green (with baseline).
- [ ] Write `docs/architecture/ARCHITECTURE.md`; verify every mermaid block renders and every internal link resolves.
- [ ] Full manual smoke of the app (all tabs, a network call, nested nav, config-change survival).

## Definition of Done

- `libraries/` contains only `testutils`; no dangling module refs.
- Konsist K2 + K7 enforced and green.
- `docs/architecture/ARCHITECTURE.md` complete, structure-parallel to the Flutter doc.
- `assembleDebug` + all existing tests green; app smoke-tested.

## Dependencies & Blockers

- Blocked by [Task 5](task_5_extract_core_module.md), [Task 6](task_6_extract_network_module.md), [Task 7](task_7_extract_framework_module.md), [Task 8](task_8_merge_ui_kit_module.md).
- Blocks [Task 10](task_10_extract_shell_thin_app.md).

## References & Rollback

- Source spec §4, §9 Phase 1.
- Rollback: this is the Phase 1 integration point — revert to the last green Phase 0 commit; module-extraction PRs can be re-applied individually.