---
id: "task_3_github_actions_ci"
status: "done"
priority: "high"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:06.439Z"
completedAt: "2026-09-03T03:30:06.439Z"
labels: ["ci", "infra"]
order: "a3"
---
# Task 3: GitHub Actions CI pipeline

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

The repo has **no CI**. Add `.github/workflows/ci.yml` — one job, triggered on `pull_request` and on push to `develop` / `epic/**`:

- `actions/checkout@v4`
- `actions/setup-java@v4` (temurin 17)
- `gradle/actions/setup-gradle@v4` (Gradle + build cache)
- `./gradlew :konsist-test:test detekt spotlessCheck testDebugUnitTest assembleDebug`
- `actions/upload-artifact@v4` for `**/build/reports/{detekt,lint,tests}` on failure

No secrets this round — do **not** wire Firebase `google-services.json` or signing (the repo's `app/build.gradle.kts` release build has `isMinifyEnabled = false` and no signing config, so `assembleDebug` needs nothing). `bundleDebug` + DFM split testing is added later in [Task 16](task_16_e2e_acceptance_validation.md).

This satisfies governance criterion 4.2 (Internal API Contract): a breaking change to a `:core`/`:platform` public type fails `assembleDebug` for every dependent module — caught at compile time, blocking the merge.

## Relevant Files & Context Pointers

- NEW: `.github/workflows/ci.yml`
- `gradlew`, `gradle/wrapper/gradle-wrapper.properties` — wrapper version the workflow pins
- `build.gradle.kts` (root), `app/build.gradle.kts` — task names (`detekt`, `spotlessCheck`, `assembleDebug`) already provided by `codeanalyzetools.*` convention plugins
- `buildSrc/src/main/kotlin/codeanalyzetools/{detekt-check,spotless,quality}.gradle.kts` — confirm the aggregate task names
- Reference: `bloc_digital_wallet/.worktrees/flutter_super_app_template/.gitlab-ci.yml` (single `CIChecking` stage — same shape, different platform)

## Design Rationale

GitHub Actions chosen by the user. One job (not a matrix) keeps first-time setup minimal and fast; the Gradle build cache carries most of the cost after the first run. Keeping secrets out of Phase 0 de-risks the initial rollout — signing/Firebase can be added as a separate hardening task later.

Applicable skill: none specific; follow `.agent/rules/CRITICAL_RULES.md` (run `@quality_check` locally before pushing).

## TDD Checklist

**TDD Adaptation** — this is CI config, no runtime behavior. Verifiable steps instead:

- [ ] Add the workflow; push the branch; confirm the job runs and passes on the current tree.
- [ ] Open a throwaway PR that adds a compile error in `:core` → confirm `assembleDebug` step fails and blocks.
- [ ] Open a throwaway PR that adds a K5 naming violation → confirm `:konsist-test:test` step fails.
- [ ] Revert both throwaway PRs.

## Definition of Done

- `.github/workflows/ci.yml` present; a green run recorded on the epic branch.
- The four negative checks above each fail the job as expected.
- Job completes in a reasonable time with warm Gradle cache (target < 15 min).

## Dependencies & Blockers

- Blocked by [Task 2](task_2_konsist_gate.md) (the `:konsist-test:test` task must exist).
- Blocks [Task 16](task_16_e2e_acceptance_validation.md) (extends this workflow with `bundleDebug`).

## References & Rollback

- Source spec §6.3.
- Rollback: delete `.github/workflows/ci.yml`.