---
id: "task_16_e2e_acceptance_validation"
status: "done"
priority: "high"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:30.840Z"
completedAt: "2026-09-03T03:30:30.840Z"
labels: ["ci", "validation", "template"]
order: "a1Z"
---
# Task 16: CI `bundleDebug` + end-to-end acceptance validation

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

Prove the whole template works from a clean clone.

1. **Extend CI** (`.github/workflows/ci.yml`): add `bundleDebug` to the Gradle invocation so the AAB with the `scanner` split is built on every PR. Add a lightweight step that runs bundletool `build-apks --local-testing` and asserts the `scanner` split APK exists (no device needed).
2. **Acceptance script / documented runbook** — from a fresh worktree of the epic branch:
   - `scripts/rename_project.sh acme_wallet com.acme.wallet "Acme Wallet"`
   - `mason make mvi_feature --name payments` (install-time) → builds, tab reachable
   - `mason make mvi_feature --name kyc --delivery on-demand` → dynamic-feature module, in `dynamicFeatures`
   - `./gradlew :konsist-test:test detekt spotlessCheck testDebugUnitTest assembleDebug bundleDebug` → **all green**
   - install via bundletool `--local-testing`; launch; verify: 3 base tabs, `settings` default; tap `scanner` → split installs → screen opens; navigate to `payments`; `kyc` split present
   - `mason make remove_feature --name payments && mason make remove_feature --name kyc` → tree back to green
3. Capture this as `docs/getting-started/TEMPLATE_ACCEPTANCE.md` (the exact command sequence + expected output) so a consumer can re-run it.

## Relevant Files & Context Pointers

- `.github/workflows/ci.yml` (from Task 3)
- `scripts/rename_project.sh` (Task 15), `bricks/mvi_feature/**` (Tasks 4 + 14)
- `features/scanner/**` (Task 14), `app/build.gradle.kts` `android.dynamicFeatures`
- NEW: `docs/getting-started/TEMPLATE_ACCEPTANCE.md`, optionally `scripts/acceptance_check.sh`
- `gradlew`, bundletool (pin a version in the workflow)
- Reference: `bloc_digital_wallet/.worktrees/flutter_super_app_template` `template_flutter` Task 8 "extraction & validation on worktree"

## Design Rationale

The epic's definition of "done" is not "modules split" but "a stranger can clone, rename, add features in both delivery modes, and ship" — this task is that proof, automated where cheap (CI `bundleDebug` + split-exists assertion) and scripted where it needs a runtime (`--local-testing` launch). Mirrors the Flutter epic's Phase 2 validation task.

Applicable skill: `@quality_check`; `verification-before-completion` — do not mark done without the captured green output.

## TDD Checklist

**TDD Adaptation** — validation harness. Verifiable steps:

- [ ] Add `bundleDebug` + bundletool split-assertion to CI; confirm a green run on the epic branch.
- [ ] Execute the full acceptance sequence on a clean worktree; capture terminal output.
- [ ] Confirm each expected outcome (green build, 3 tabs, scanner split install, both new features).
- [ ] Run the `remove_feature` teardown; confirm return to green.
- [ ] Commit `docs/getting-started/TEMPLATE_ACCEPTANCE.md` with the captured evidence.

## Definition of Done

- CI builds `bundleDebug` and asserts the `scanner` split on every PR.
- The documented acceptance sequence runs green end-to-end from a fresh worktree, evidence captured in `TEMPLATE_ACCEPTANCE.md`.
- Both `--delivery` modes of `mvi_feature` produce buildable, wired features; `remove_feature` reverses them.
- Konsist gate green with an empty (or one-documented-entry) whitelist.

## Dependencies & Blockers

- Blocked by [Task 14](task_14_scanner_dynamic_feature.md), [Task 15](task_15_rename_script_and_docs.md), [Task 3](task_3_github_actions_ci.md).
- Final task of the epic.

## References & Rollback

- Source spec §9 Phase 3 acceptance test.
- Rollback: n/a (validation only) — a failure here reopens the task it exposed, not this one.