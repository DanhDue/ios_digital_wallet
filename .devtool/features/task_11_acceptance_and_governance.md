---
id: "task_11_acceptance_and_governance"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T03:32:30+07:00"
modified: "2026-09-19T04:47:44+07:00"
completedAt: null
labels: ["integration", "acceptance", "archtests", "governance", "coverage", "tier-c"]
order: "a11"
---

# Task 11: Tier C Acceptance, Governance & Coverage Tooling

Epic Reference: [pulse_logger](../epic/pulse_logger/pulse_logger.en.md) · BDD: [bdd_scenarios.md](../epic/pulse_logger/bdd_scenarios.md) UC-7, Cross-cutting

## Requirement Analysis

Run the full Tier A / B / C acceptance pass and **make Gate 4's numbers real**.

The source spec set line-coverage thresholds (≥85% domain, 100% security) and the lifecycle's Gate 4
enforces them — but CI currently runs `swift test` with no `--enable-code-coverage` and the repo has
no threshold script. Those numbers were therefore unmeasurable, and reporting them green would have
been a fabricated pass. Building that tooling is part of this task, not a follow-up.

## Relevant Files & Context Pointers

- `scripts/check_coverage_thresholds.sh` — create
- `.github/workflows/ci.yml` — modify: enable coverage in the package loop; run the threshold script;
  run `check_release_isolation.sh`
- `ArchTests/Tests/ArchTests/**` — verify, extend if a rule gap surfaced during the epic
- `scripts/check_module_boundaries.sh` — run, do not modify
- `quality/.swiftlint.yml`, `quality/.swiftformat` — run, do not modify
- `App/Tests/AppTests/**`, `App/UITests/AppUITests/**` — extend with the end-to-end logging flow
- `docs/architecture/ARCHITECTURE.md` — verify Task 6's doc sync is still accurate after Tasks 7–9

## Design Rationale

- **Coverage measurement over coverage claims.** `swift test --enable-code-coverage` plus
  `xcrun llvm-cov export` gives per-file line coverage; the script maps the HLD §5.6 table onto path
  globs and exits non-zero on any shortfall. Thresholds live in one place so they can be raised
  without touching CI YAML.
- **Per-area thresholds, not one repo-wide number.** A single global percentage would let 100%
  coverage on trivial model code paper over an untested redactor. The table is deliberately uneven:
  `Redaction/**` and `Trace/**` at 100%, dispatch at 90%, appenders and bridge at 85%, UI at 80%.
- **The leak gate is a runtime check, not an assertion.** Enable `MallocStackLogging` on the test
  scheme and run `leaks` against the process after an end-to-end flow. `trackForMemoryLeaks` catches
  what tests construct; `leaks` catches what the composition root retains.
- **Check 2 (Shift-Right bookend).** Re-run `check_code_impact.py` against `develop` over the
  cumulative diff to confirm zero divergence from the Check 1 prediction in HLD §5.4 — in particular
  that the 22 downstream callers really were reached through the adapter and not edited.
- **Mode sweep is part of acceptance.** `enterprise` and `lean` must both generate and build;
  `plugin` must be provably untouched.

Applicable skills: `quality_check`, `architecture-audit`, `security-audit`, `code-health-audit`,
`impact-analysis`.

## Impact Analysis & Blast Radius

- **Target symbols**: CI workflow, the coverage script, ArchTests, host test targets.
- **Downstream callers**: the CI pipeline and every future PR — a threshold script that is too strict
  blocks unrelated work, so calibrate against the measured baseline before enabling it.
- **Cross-platform bridges**: none.
- **Coverage threshold**: this task *is* the threshold.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

Authoritative copies in [bdd_scenarios.md](../epic/pulse_logger/bdd_scenarios.md). This task verifies:

- **UC-7.2** — a host-app session under `MallocStackLogging` shows zero leaked logging objects after
  a flow that logs and performs a request.
- **Cross-cutting** — `ArchTests` K1–K10 all pass with the new package present, `HostRulesTests`
  lists `D3NexusLogging` among the forbidden `Core` siblings, and both `enterprise` and `lean`
  generate and build while `plugin` is unaffected.

Plus, specific to this task:

```gherkin
[Tier B - Governance]
Scenario: The coverage gate fails loudly when a threshold is missed
  Given the coverage threshold script configured from HLD section 5.6
  When a redaction source line is deliberately left uncovered
  Then the script exits non-zero and names the file and the shortfall
  # RED-then-GREEN: prove the gate fires before trusting it.
```

```gherkin
[Tier B - Governance]
Scenario: Check 2 confirms the predicted blast radius held
  Given the cumulative epic diff against develop
  When check_code_impact.py is run in shift-right mode
  Then it reports zero divergence from the Check 1 prediction
  And none of the 22 downstream caller files appear as modified
```

## Test & Verification Checklist

- [ ] **Tier A** — every package suite green:
      `swift test --package-path Packages/D3NexusLogging`,
      `Packages/Core`, `Packages/Network`, `Features/Settings`, with `trackForMemoryLeaks` clean.
- [ ] **Coverage** — build `scripts/check_coverage_thresholds.sh`, prove it fires on an injected
      gap, revert the injection, and confirm every HLD §5.6 threshold is met.
- [ ] **Tier B** — `swift test --package-path ArchTests`;
      `bash scripts/check_module_boundaries.sh`;
      `swiftlint lint --strict --config quality/.swiftlint.yml`;
      `swiftformat --config quality/.swiftformat . --lint`;
      `bash scripts/check_release_isolation.sh`.
- [ ] **Tier C** — `tuist generate --no-open` then
      `xcodebuild test -workspace iOSDigitalWallet.xcworkspace -scheme iOSDigitalWallet -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO`;
      repeat for `lean`; confirm `plugin` untouched.
- [ ] **Leak gate** — `MallocStackLogging` enabled, `leaks` reports zero logging retention.
- [ ] **Leak gate fires** — run the same check against a build that exercises Task 10's leaking demo
      flow and confirm `leaks` **does** report it, then revert. Same RED-then-GREEN discipline the
      coverage gate and K7 are held to: a gate that has never been seen to fail is not evidence.
- [ ] **Check 2** — `check_code_impact.py --base-ref develop` over the cumulative diff.
- [ ] **Extraction readiness (E1–E4)** — verify `Packages/D3NexusLogging/Package.swift` declares no
      `.package(path:)` dependency on this repository; copy the package directory to a scratch
      location outside the repo and confirm `swift build` and `swift test` still pass there; confirm
      every `public` symbol carries a doc comment; confirm `OSLogAppender` has no app-derived default
      subsystem and `Redactor` accepts injected rules.
- [ ] **Final** — invoke the `quality_check` skill for the Gate 4 verdict. A 🟢 must come from a
      complete run, never from re-running only what previously failed.

## Definition of Done (DoD)

- All four Gate 4 conditions satisfied: 3-tier suite 100% pass; Security / Architecture / UI / Code
  Health audits with zero blockers; reverse-verification coverage met per HLD §5.6; Check 2 clean.
- The coverage gate is wired into CI and proven to fire on a real shortfall.
- `check_release_isolation.sh` wired into CI and passing.
- `enterprise` and `lean` both generate and build; `plugin` unaffected.
- Zero leaked logging objects under `leaks`.
- `ARCHITECTURE.md` verified accurate against the final graph.
- `quality_check` returns 🟢 LGTM.

## Dependencies & Blockers

- Blocked by: [Task 10](task_10_leak_sentinel_and_demo.md).
- Blocks: Gate 5 (developer Kanban review and sign-off).

## References & Rollback

- Gate 4 acceptance criteria — `dev-lifecycle` skill, Stage 3
- HLD §5.6 coverage thresholds — [pulse_logger.en.md](../epic/pulse_logger/pulse_logger.en.md)
- Rollback: this task adds gates, not behaviour. Reverting it removes enforcement; it never breaks
  the app.
