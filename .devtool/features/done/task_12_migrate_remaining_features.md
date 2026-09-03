---
id: "task_12_migrate_remaining_features"
status: "done"
priority: "medium"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:19.365Z"
completedAt: "2026-09-03T03:30:19.365Z"
labels: ["architecture", "governance"]
order: "a2G"
---
# Task 12: Migrate remaining feature cross-imports → empty whitelist

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

In the **source repo** (digital-wallet, before the template cut) there may still be cross-feature couplings other than the `home→*` set already resolved — e.g. `authentication` ↔ `settings`, or a feature reaching into `myWallet`. Drive `konsist_boundary_whitelist.txt` to **empty**:

- For each remaining `X→Y` entry: replace the import with either (a) navigation via `AppRoutes` (if it was a screen jump), (b) an `AppEvent` (if it was a fire-and-forget signal), or (c) Dependency Inversion — an interface in `:core` implemented by `Y`, injected into `X` (if it needs a typed result from `Y`'s business logic).
- Delete the entry; confirm re-adding the import now fails CI.
- Flip Konsist **K1** to fail mode (no whitelist consulted → any cross-feature import fails).

If a coupling genuinely cannot be resolved without disproportionate work, it may stay as the single documented whitelist entry (matches the Flutter epic ending with one ratified `onboard→settings` exception) — but document *why* in the whitelist file and the epic Meta Data.

## Relevant Files & Context Pointers

- `scripts/konsist_boundary_whitelist.txt`
- `features/*/src/main/*/com/danhdue/*/**` — the importing/imported sites
- `platform/src/main/kotlin/com/danhdue/platform/{AppRoutes,AppEvent}.kt` — targets for (a)/(b)
- `core/src/main/kotlin/com/danhdue/core/**` — home for any inverted interface (c)
- `konsist-test/src/test/kotlin/com/danhdue/konsist/BoundaryRulesTest.kt` — flip K1
- Reference: `bloc_digital_wallet/.worktrees/flutter_super_app_template` super_app_governance Phase 1-2 migration notes

## Design Rationale

Each of the three resolution patterns is already established by earlier tasks (routes in Task 11, events in Task 11, DI interfaces in `:core` per Goal G5). This task is applying them feature-by-feature until the gate can run with no exceptions.

Applicable skill: `@quality_check` after each feature migrated.

## TDD Checklist

**TDD Adaptation** — decoupling refactor per site (behavior preserved). Verifiable steps, repeated per whitelist entry:

- [ ] Identify what the import was used for; choose pattern (a)/(b)/(c).
- [ ] Apply it; delete the import and the whitelist line.
- [ ] Run the affected features' `testDebugUnitTest` — no regression; add a test for any new interface (c).
- [ ] `./gradlew :konsist-test:test` green with the shrunk whitelist.
- [ ] After the last entry: flip K1 to fail; full `assembleDebug testDebugUnitTest` green; app smoke-tested.

## Definition of Done

- `konsist_boundary_whitelist.txt` empty (or exactly one documented, justified entry).
- Konsist K1 in fail mode.
- All feature flows behave as before (smoke-tested); all tests green; `assembleDebug` green.

## Dependencies & Blockers

- Blocked by [Task 11](task_11_platform_routes_settings_pilot.md).
- Blocks [Task 13](task_13_strip_domain_to_template.md).

## References & Rollback

- Source spec §6.1 (K1), §9 Phase 3.
- Rollback: re-add whitelist entries and revert K1 to whitelist-consulting mode; individual decoupling refactors can remain.