---
id: "task_10_acceptance_verification_and_docs"
status: "todo"
priority: "high"
assignee: null
epic: "tri_mode_and_flutter_plugin_devbed"
dueDate: null
created: "2026-09-13T21:30:41Z"
modified: "2026-09-13T21:30:41Z"
completedAt: null
labels: ["testing", "documentation", "ci"]
order: "a10"
---

# Task 10: Acceptance Verification & Documentation (Tier C)

Epic: [tri_mode_and_flutter_plugin_devbed](../epic/tri_mode_and_flutter_plugin_devbed/tri_mode_and_flutter_plugin_devbed.en.md)

## Requirement Analysis

The System Integration Engineer task that closes the epic. Nothing new is built here; everything
is proven end to end, automated, and written down.

Three deliverables:

1. **`scripts/acceptance_check.sh`** — one command running the full verification matrix V1–V11
   from the source spec, mirroring `android_digital_wallet/scripts/acceptance_check.sh`.
2. **Documentation** — `docs/architecture/TEMPLATE_MODES.md` (the three modes, when to pick each,
   how to switch), `docs/architecture/PLUGIN_DEVBED.md` (completed from Task 5's stub: bootstrap,
   the `xcodebuild` invocation, the plugin authoring loop), plus `README.md` and `AGENTS.md`
   updates so both humans and agents learn the modes exist.
3. **CI** — a new job in `.github/workflows/ci.yml` that installs the Flutter SDK and verifies
   plugin mode. The existing `quality` and `packages` jobs stay exactly as they are.

The acceptance bar is the full matrix passing from a clean clone, including the four-state round
trip `enterprise → lean → plugin → enterprise`.

## Relevant Files & Context Pointers

- `scripts/acceptance_check.sh` — **new**.
- `docs/architecture/TEMPLATE_MODES.md` — **new**.
- `docs/architecture/PLUGIN_DEVBED.md` — started in Task 5, completed here.
- `docs/architecture/ARCHITECTURE.md` — link the two new documents.
- `README.md` — mode selection in the getting-started flow.
- `AGENTS.md` — a Modes section so agents pick the right commands per mode.
- `.github/workflows/ci.yml` — currently two jobs (`quality`, `packages`); add a third.
- Verification matrix V1–V11:
  [2026-09-14-tri-mode-template-and-flutter-plugin-devbed-design.md](../epic/tri_mode_and_flutter_plugin_devbed/2026-09-14-tri-mode-template-and-flutter-plugin-devbed-design.md) §8.
- Android reference: `android_digital_wallet/scripts/acceptance_check.sh`.

## Design Rationale

- **One command, not a checklist.** A matrix a human must remember to run is a matrix that stops
  being run. `acceptance_check.sh` is what makes V1–V11 durable.
- **A separate CI job for plugin mode.** Installing Flutter in the existing `quality` job would
  slow every PR for a capability most PRs do not touch; a third job keeps the fast path fast.
- **`AGENTS.md` must document modes.** Agents read it as their entry point; without a Modes
  section, an agent in lean mode will keep trying to run `ArchTests` and report false failures.
- **Documentation is a deliverable, not a postscript.** A mode system nobody knows how to use has
  shipped nothing.
- **Applicable skills**: `quality_check` (the Gate 4 verdict), `pr_review`, `ArchTests`, Tuist.

### BDD SCENARIOS

Canonical source: [bdd_scenarios.md](../epic/tri_mode_and_flutter_plugin_devbed/bdd_scenarios.md) S5, S21, S22.

```gherkin
Scenario: The acceptance harness runs the full matrix  [Tier C - Integration]
  Given a clean clone with the toolchain installed via mise
  When I run "./scripts/acceptance_check.sh"
  Then every check V1 through V11 executes
  And the script exits zero only if all of them pass
  And a summary names each check and its result

Scenario: The four-state round trip is clean  [Tier C - Integration]
  Given a clean git tree in enterprise mode
  When I run configure_mode.sh for lean, then plugin, then enterprise
  Then the build is green at each state
  And the test suite is green at each host state
  And the final tree differs from the initial tree only in generated artefacts

Scenario: Enterprise mode passes the full governance gate  [Tier C - Integration]
  Given the project is in enterprise mode
  When the acceptance harness runs
  Then ArchTests K1-K10 pass, including deep-link reachability K10.2
  And check_module_boundaries.sh passes
  And swiftlint --strict and swiftformat --lint are clean

Scenario: Lean mode is measurably faster  [Tier C - Integration]
  Given a cold build in each host mode
  When the harness measures verification wall time
  Then lean completes faster than enterprise
  And the report states that lean skipped ArchTests

Scenario: Plugin mode is verified in CI  [Tier C - Integration]
  Given the CI workflow runs on a pull request
  When the plugin-mode job executes
  Then it installs the Flutter SDK and bootstraps the devbed
  And it builds and tests the Plugin scheme and builds the Sample scheme
  And the quality and packages jobs are unaffected

Scenario: Documentation covers every mode  [Tier C - Integration]
  Given the docs have been written
  Then TEMPLATE_MODES.md describes all three modes and when to choose each
  And PLUGIN_DEVBED.md documents bootstrap, the xcodebuild invocation and the authoring loop
  And README.md and AGENTS.md both point at them

Scenario: Agents are told which commands apply per mode  [Tier A - Unit]
  Given AGENTS.md has a Modes section
  When an agent reads it while the project is in lean mode
  Then it learns that ArchTests is intentionally skipped
  And it does not report the absence of ArchTests as a failure

Scenario: The harness fails loudly on a broken mode  [Tier A - Unit]
  Given a deliberately corrupted marker region
  When "./scripts/acceptance_check.sh" runs
  Then it exits non-zero
  And the summary names the failing check
```

## Test & Verification Checklist

- [ ] **RED**: Write `acceptance_check.sh` so that every check initially reports NOT RUN, and the
      script exits non-zero until all of V1–V11 are wired and passing.
- [ ] **GREEN**: Wire each check; write the four documents; add the CI job.
- [ ] **REFACTOR**: `shellcheck` clean; each check its own function under 20 lines; the summary
      readable in CI logs.
- [ ] **Tier A**: `xcodebuild test -scheme Plugin` green in plugin mode.
- [ ] **Tier B**: In enterprise mode — `swift test --package-path ArchTests`,
      `bash scripts/check_module_boundaries.sh`,
      `swiftlint lint --strict --config quality/.swiftlint.yml`,
      `swiftformat --config quality/.swiftformat . --lint` all pass.
- [ ] **Tier C**: `./scripts/acceptance_check.sh` green from a clean clone; CI green on all three
      jobs; `tuist generate --no-open && xcodebuild test` green in enterprise and lean.

## Definition of Done

- `scripts/acceptance_check.sh` runs V1–V11 and gates on all of them.
- The four-state round trip is green end to end.
- `TEMPLATE_MODES.md` and `PLUGIN_DEVBED.md` written; `ARCHITECTURE.md`, `README.md` and
  `AGENTS.md` updated.
- CI has a plugin-mode job; `quality` and `packages` unchanged and still green.
- `quality_check` returns a 🟢 LGTM — this is the epic's Gate 4.
- Clean `git status` after the commit.

## Dependencies & Blockers

- Blocked by every preceding task: [1](task_1_marker_regions_and_mode_seam.md),
  [2](task_2_configure_mode_script.md), [3](task_3_mode_aware_test_suite.md),
  [4](task_4_rename_project_mode_integration.md),
  [5](task_5_bootstrap_devbed_flutter_binding.md),
  [6](task_6_scaffold_plugin_clean_architecture.md), [7](task_7_flutter_platform_layer.md),
  [8](task_8_scaffold_sample_runner_app.md), [9](task_9_native_plugin_mason_bricks.md).
- Blocks nothing — this is the final task, and its green run is Gate 4.

## References & Rollback

- Source spec §8 (verification matrix), §9 (risks); HLD §6 (rollout).
- Android reference: `android_digital_wallet/scripts/acceptance_check.sh`.
- **Rollback**: revert the commit. All functional work from Tasks 1–9 remains; only the automated
  harness, docs and CI job are lost, and the epic then cannot pass Gate 4.
