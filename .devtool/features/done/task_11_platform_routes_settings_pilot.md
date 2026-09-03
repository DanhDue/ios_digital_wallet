---
id: "task_11_platform_routes_settings_pilot"
status: "done"
priority: "high"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:16.663Z"
completedAt: "2026-09-03T03:30:16.663Z"
labels: ["architecture", "governance", "pilot"]
order: "a2V"
---
# Task 11: Relocate cross-feature `NavKey`s + `settings` pilot + enable strict gate

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

Prove the cross-feature contract end-to-end on one feature, then tighten enforcement.

1. **Relocate cross-feature `NavKey`s** — any `*Route : NavKey` referenced by a module other than its owning feature moves from `..features..presentation..` into `:platform`'s `AppRoutes` (Konsist K9). Sweep all `features/*/presentation/*Route.kt`; feature-private routes stay put.
2. **`settings` pilot**:
   - all navigation to/from `settings` goes through `AppRoutes.SettingsRoute` + `Navigator`/`NestedNavigator` — no other module imports `com.danhdue.settings.*`
   - `settings` publishes one real `AppEvent` (e.g. `LocaleChanged` or `ProfileUpdated`) via `AppEventBus`; `:shell` subscribes with `on<T>()` and reacts (e.g. refresh a shell-level label). This closes the Android analogue of the Flutter shell's `// TODO: notify tab`.
   - wire `:network`'s 401 interceptor to `AppEventBus.publish(UserLoggedOut)` (the `// TODO(task_11)` marker from Task 6); `:shell` or an app initializer subscribes and navigates to login.
3. **Tighten the gate**:
   - Gradle guard in `commons.android-feature` → **fail** mode (throw instead of log)
   - Konsist **K4** (export discipline — `data/**` must be `internal`), **K6** (host privilege), **K9** (NavKey location) → enforced. Add baseline entries only for genuine pre-existing violations, each with a cleanup `// TODO`.
   - `konsist_boundary_whitelist.txt` should be down to **≤ 1** entry (only the hardest remaining business-logic coupling in the source repo, if any).

## Relevant Files & Context Pointers

- `features/*/src/main/*/com/danhdue/*/presentation/*Route.kt` — sweep for cross-feature keys
- `platform/src/main/kotlin/com/danhdue/platform/{AppRoutes,AppEvent,AppEventBus}.kt`
- `features/settings/src/main/kotlin/com/danhdue/settings/**` — the pilot
- `shell/src/main/kotlin/com/danhdue/shell/**` — subscriber side
- `network/src/main/kotlin/com/danhdue/network/{interceptor,authenticator}/**` — `UserLoggedOut` publish point
- `buildSrc/src/main/kotlin/commons/android-feature.gradle.kts` — flip guard to fail
- `konsist-test/src/test/kotlin/com/danhdue/konsist/**` — enable K4/K6/K9
- `scripts/konsist_boundary_whitelist.txt`
- Reference: `bloc_digital_wallet/.worktrees/flutter_super_app_template` Task 6 "migrate settings pilot"

## Design Rationale

`settings` is the pilot because it is the feature both `:shell` and (in the source repo) other features touch — exercising both navigation and event directions in one migration, mirroring the Flutter epic's pilot choice. Flipping the guard/rules to fail *after* a proven pilot means the strict gate lands on a tree that already passes it.

Applicable skills: `@api_integration` (401/refresh interaction); `@quality_check` after.

## TDD Checklist

- [ ] **RED**: `SettingsEventContractTest` — publishing the settings `AppEvent` is received by a shell-side subscriber; `UserLoggedOut` from a simulated 401 triggers the login-nav side effect.
- [ ] **RED**: Konsist K4/K6/K9 tests fail against a deliberately-planted violation, pass once removed.
- [ ] **GREEN**: relocate routes; wire settings publish + shell/app subscribe; wire 401 → `UserLoggedOut`.
- [ ] **REFACTOR**: flip Gradle guard to fail; enable K4/K6/K9; shrink whitelist; document any remaining entry.
- [ ] Manual smoke: navigate to settings via `AppRoutes`, trigger the event, observe shell reaction; force a 401, land on login.

## Definition of Done

- No module imports `com.danhdue.settings.*` except `settings` itself.
- One real `AppEventBus` publish/subscribe pair working (settings→shell) + `UserLoggedOut` wired.
- Gradle guard in fail mode; Konsist K4/K6/K9 enforced and green.
- `konsist_boundary_whitelist.txt` ≤ 1 entry.
- All tests green; `assembleDebug` green; pilot flow smoke-tested.

## Dependencies & Blockers

- Blocked by [Task 10](task_10_extract_shell_thin_app.md), [Task 1](task_1_platform_module.md), [Task 2](task_2_konsist_gate.md).
- Blocks [Task 12](task_12_migrate_remaining_features.md).

## References & Rollback

- Source spec §5, §6, §9 Phase 2.
- Rollback: re-add whitelist entries; revert the guard/rule flips to warn/report-only — the pilot code changes can stay.