# Failure Analysis — Task 13: CI, Remove the xcodebuild test→build Fallback

Captured from the implementer's QA pass at implementation time (2026-09-11).
This task is a CI configuration change, so the repo's Tier B standard applies
instead of RED-first TDD: the record below enumerates every way the app job can
fail once the fallback is gone, and which of those the fallback had been masking.
Task: [task_13_ci_test_fallback_removal](../../../features/task_13_ci_test_fallback_removal.md)

## PHASE 1 — FAILURE ANALYSIS (QA / Red Team persona)

### FAILURE ANALYSIS

```gherkin
Feature: app job failure modes once the test->build fallback is removed

  Scenario: A genuinely failing unit test
    Given App/Tests/AppTests contains an assertion that no longer holds
    When "xcodebuild test" runs in the app job
    Then xcodebuild exits non-zero
    And the app job goes red
    # Classification: REAL DEFECT. This is exactly the case CI must catch.

  Scenario: A genuinely failing UI test
    Given App/UITests/DeepLinkOpenURLUITests asserts a screen/element that the
      app under test no longer produces
    When "xcodebuild test" runs the UI test bundle as part of the same testAction
    Then xcodebuild exits non-zero
    And the app job goes red
    # Classification: REAL DEFECT, same tier as a unit test failure — this is
    # the whole reason Task 9's acceptance suite was added.

  Scenario: A flaky UI test (timing, simulator boot, SpringBoard)
    Given the UI test suite is subject to XCUITest's known flakiness sources
      (element-wait timeouts, SpringBoard animation timing, automation-session
      setup races)
    When the flake fires on an otherwise-correct app
    Then xcodebuild exits non-zero for a reason unrelated to the code change
    And the app job goes red
    # Classification: NOISE (infrastructure), but only detectable by rerunning —
    # CI cannot distinguish this from a real UI regression by exit code alone.
    # This is the direct cost of removing the fallback and is called out
    # explicitly in carried note 2.

  Scenario: A destination that does not exist on the runner
    Given the destination specifier names a simulator/OS combination absent
      from the runner's installed Xcode
    When "xcodebuild test" resolves the -destination argument
    Then xcodebuild exits non-zero with "Unable to find a destination matching..."
    And the app job goes red for a reason that has nothing to do with the code
    # Classification: NOISE (infrastructure / CI config), not a code defect.
    # IMPORTANT: this was NOT masked by the old fallback — the else branch
    # reused the identical $destination string for `xcodebuild build`, so a
    # bad destination fails both branches identically. This scenario already
    # reds the job today; the edit does not change its behavior. It is
    # addressed separately in this task via the destination-selection change
    # (carried note 3), not by the fallback removal itself.

  Scenario: A "tuist generate" or SPM resolution failure
    Given "tuist install" or "tuist generate --no-open" fails
      (dependency resolution error, cache corruption, plugin fetch failure)
    When that step runs, prior to "Build & test the app"
    Then the step itself exits non-zero
    And the app job goes red before xcodebuild is ever invoked
    # Classification: NOISE-or-real depending on cause, but structurally
    # UNRELATED to this task: these are separate steps in the job with no
    # if/else wrapper, so they were never masked by the fallback and are
    # unaffected by this edit.

  Scenario: A simulator that fails to boot at all
    Given the target simulator cannot boot (corrupted simulator state, runner
      resource exhaustion, CoreSimulator service failure)
    When "xcodebuild test" attempts to install and launch the test runner
    Then xcodebuild exits non-zero because tests could not execute
    But a subsequent "xcodebuild build" of the same scheme/destination
      typically succeeds anyway, because a plain build does not require the
      simulator to boot
    # Classification: NOISE (infrastructure), but this is precisely the case
    # that most clearly demonstrates why the fallback was dangerous: build
    # succeeding says nothing about whether the app or its tests are correct,
    # yet it produced a green job.
```

**What the old fallback was masking:** every scenario where `xcodebuild test`
itself fails for any reason — genuinely failing unit tests, genuinely failing
UI tests, UI-test flakes, and simulator boot failures — because `xcodebuild
build` on the same destination does not execute tests and will happily
succeed even when the app is broken by its own test suite's standard, or when
the simulator is unable to run anything at all. This is the direct hole in
governance criterion 4.2.

**What the old fallback was NOT masking** (already surfaced today, unaffected
by removing it): a bad `-destination` specifier and any `tuist
install`/`tuist generate` failure. The former fails identically in both
branches of the old if/else (same destination string reused verbatim); the
latter happens in separate steps outside the if/else entirely.

**What the edited workflow newly surfaces:** genuinely failing unit tests,
genuinely failing UI tests, and — as an accepted cost — UI-test flakes and
simulator-boot failures, all of which now correctly fail the job instead of
silently degrading to a build-only pass.

---

