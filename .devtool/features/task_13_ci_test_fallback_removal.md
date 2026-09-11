---
id: "task_13_ci_test_fallback_removal"
status: "in-progress"
priority: "high"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-11T13:05:08+07:00"
completedAt: "2026-09-11T13:05:08+07:00"
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

## Carried notes from Task 9's review — read before editing the workflow

1. **`-workspace` is not optional in this repo.** `xcodebuild test -scheme iOSDigitalWallet`
   without `-workspace iOSDigitalWallet.xcworkspace` is unreliable here (a
   pre-existing implicit-dependency resolution problem, not caused by this epic).
   The current `ci.yml` already passes it — **keep it**. Removing the fallback must
   not quietly also drop the flag.
2. **The UI tests share the scheme's `testAction`.** Task 9 added
   `App/UITests` and wired it into the same scheme, so once the fallback is gone a
   single XCUITest flake reds the whole `app` job. That may well be what you want —
   an acceptance test that can be ignored is worthless — but it is a deliberate
   choice, not an accident. State in the report which you chose and why.
3. **The `iPhone 16` pin is already brittle.** `ci.yml` hard-codes
   `name=iPhone 16,OS=latest`; that device does not exist on this machine
   (available: iPhone 17 Pro / 17 / 16e / Air) and may or may not exist on the
   `macos-15` runner image. With the fallback in place a bad destination silently
   degraded to a build; without it, the job goes red for a reason that has nothing
   to do with the code. Prefer a destination that cannot vanish — e.g. selecting by
   platform rather than by device name — over pinning a model.

## Definition of Done — CI-proof item, restated honestly

The original DoD asked for "a PR with an intentionally failing app test produced a
**red** `app` job — run URL recorded". That requires pushing this branch to
`origin` and opening a pull request, which is an outward-facing action outside an
implementer's remit. Split it:

- **Achievable locally, and required:** run the exact command the workflow will
  run, against a deliberately broken app test, and show it exits non-zero — then
  revert. This proves the command itself fails rather than degrading.
- **Requires a push, and is the epic owner's call:** the GitHub run. Record it as
  outstanding rather than claiming it; do not push.

## Dependencies & Blockers

- Blocked by nothing. This task has no code dependency on any other.
- **Recommended placement: early.** It was first written to land beside
  [Task 9](task_9_tier_c_acceptance_suite.md) so that suite would be enforced on
  arrival, but running it first is strictly better: every remaining task in the
  epic then gets honest CI instead of only the last few. Its own DoD (prove the
  job goes red on a deliberately broken test) does not depend on Task 9.
- Blocks nothing.

## References & Rollback

- Failure analysis captured at implementation time: [task-13-ci-test-fallback-removal.md](../epic/ios_deeplink_router/bdd/task-13-ci-test-fallback-removal.md)
- Source Spec §9 (CI hardening), §1.2 criterion 4.2 scorecard row.
- `.github/workflows/ci.yml` — current job definitions.
- **Rollback**: restore the `if/else` block. Note in the PR that doing so
  re-opens the 4.2 governance hole, so a rollback needs a stated reason and a
  follow-up issue — not a silent revert.
