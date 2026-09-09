---
id: "task_13_ci_test_fallback_removal"
status: "todo"
priority: "high"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T03:42:16+07:00"
completedAt: null
labels: ["ci", "governance", "infrastructure"]
order: "a13"
---

# Task 13: CI — Remove the xcodebuild test→build Fallback

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

`.github/workflows/ci.yml`, job `app`, currently reads:

```yaml
if xcodebuild test … ; then
  echo "xcodebuild test succeeded."
else
  echo "xcodebuild test failed (expected until Phase 1 adds test targets) — building instead."
  xcodebuild build …
fi
```

The fallback was correct when written: Phase 0 had no test target, so
`xcodebuild test` failed for a structural reason. That is no longer true —
`App/Tests/AppTests` has existed since the template's Task 12. Today the branch
converts **any** failing app test into a green CI run, which is a direct hole in
governance criterion 4.2 ("CI must go red and block the merge").

This is scoped into this epic rather than deferred because
[Task 9](task_9_tier_c_acceptance_suite.md)'s acceptance suite is otherwise
unenforceable — six end-to-end scenarios that CI is free to ignore.

**Change:** `xcodebuild test` becomes the sole command in the step; its failure
fails the job.

**Order of work matters.** Run the suite on `develop` *before* removing the
fallback. If something is already failing, that is a pre-existing defect this
task surfaces — fix it or report it explicitly; do not remove the fallback and
leave `develop` red.

## Relevant Files & Context Pointers

- `.github/workflows/ci.yml` — job `app`, step "Build & test the app"
- `App/Tests/AppTests/` — the test target that has existed since template Task 12
- `App/Tests/AppTests/DeepLinkFlowTests.swift` — from [Task 9](task_9_tier_c_acceptance_suite.md), the suite this protects
- `Project.swift` — `Module.appTestTarget` declaration and the scheme's `testAction`
- `.devtool/epic/ios_super_app_template/task_3_ios_archtests_ci_docs.md` — where the fallback originated

## Design Rationale

- **Delete, do not weaken.** Alternatives such as "fall back only when the error
  is `no test targets`" reintroduce a conditional whose correctness nobody will
  re-verify. The test target exists and is declared in the scheme's `testAction`;
  there is no legitimate remaining case for the fallback.
- **The other two CI jobs are already strict.** `quality` and `packages` fail on
  any non-zero exit. This change makes `app` consistent with them rather than
  inventing a new policy.
- **`needs: [quality, packages]` stays.** Nothing about job ordering changes.
- Applicable skill in `.agents/skills/`: **`verification-before-completion`** —
  the DoD is a real CI run, not a reading of the YAML.

## TDD Checklist

**TDD Adaptation:** this is a CI configuration change with no runtime behaviour
to drive RED-first. Concrete verifiable steps replace RED/GREEN/REFACTOR, per the
repo's Tier B standard; the substitution is stated rather than dropped.

- [ ] Run `tuist generate --no-open && xcodebuild test -scheme iOSDigitalWallet`
      locally on `develop` **before** editing CI; record the result. If anything
      fails, fix or report it first — do not proceed while `develop` is red.
- [ ] Edit `ci.yml`: replace the `if/else` with a single `xcodebuild test`
      invocation, keeping `set -o pipefail`, the destination, and
      `CODE_SIGNING_ALLOWED=NO`.
- [ ] **Prove it fails**: push a branch with one deliberately broken assertion in
      `AppTests` and confirm the `app` job goes **red**. This is the whole point
      of the task and must be demonstrated, not assumed.
- [ ] Revert the deliberate break; confirm the job goes green.
- [ ] Confirm the stale comment about "expected until Phase 1" is gone.

## Definition of Done

- [ ] `ci.yml` job `app` runs `xcodebuild test` with no fallback branch.
- [ ] A PR with an intentionally failing app test produced a **red** `app` job —
      run URL or pasted output recorded in the PR.
- [ ] A clean PR produces a green `app` job.
- [ ] No change to the `quality` or `packages` jobs, and no change to
      `needs: [quality, packages]`.
- [ ] The obsolete Phase 0 comment is removed rather than left misleading.

## Dependencies & Blockers

- Blocked by nothing technically; **should land alongside or immediately after**
  [Task 9](task_9_tier_c_acceptance_suite.md) so the acceptance suite is
  enforced from the moment it exists.
- Blocks nothing.

## References & Rollback

- Source Spec §9 (CI hardening), §1.2 criterion 4.2 scorecard row.
- `.github/workflows/ci.yml` — current job definitions.
- **Rollback**: restore the `if/else` block. Note in the PR that doing so
  re-opens the 4.2 governance hole, so a rollback needs a stated reason and a
  follow-up issue — not a silent revert.
