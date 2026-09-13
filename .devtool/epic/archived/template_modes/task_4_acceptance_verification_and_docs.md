---
id: "task_4_acceptance_verification_and_docs"
status: "todo"
priority: "high"
assignee: null
epic: "template_modes"
dueDate: null
created: "2026-09-14T04:12:15Z"
modified: "2026-09-14T04:12:15Z"
completedAt: null
labels: ["acceptance", "testing", "documentation"]
order: "a4"
---

# Task 4: Acceptance Verification & Documentation (Tier C)

Epic: [template_modes](template_modes.en.md)

## Requirement Analysis
Perform end-to-end integration and acceptance testing for the entire dual-mode system, and document the mode configuration workflows in developer documentation:
1. **Idempotency Round-Trip**:
   - Verify `enterprise` -> `lean` -> `enterprise` transition leaves a pristine, compiling, and fully tested codebase.
2. **Lean Prune Verification**:
   - Verify `--prune` physically deletes `Features/Scanner/` and the resulting project compiles and runs cleanly without missing file errors.
3. **Project Rename End-to-End**:
   - Test `./scripts/rename_project.sh` with `--mode lean` on a clone/fixture to ensure clean simulator build.
4. **Documentation**:
   - Update `README.md` to document the Dual-Mode options, flags, and build time benefits.
   - Update `docs/architecture/ARCHITECTURE.md` (or relevant architecture guides) explaining how template modes work.

## Relevant Files & Context Pointers
- `README.md`
- `docs/architecture/ARCHITECTURE.md`
- `scripts/configure_mode.sh`
- `scripts/rename_project.sh`
- `Tuist/Package.swift`
- `Project.swift`

## Design Rationale
- High-quality living documentation ensures developers immediately understand how to select between Enterprise and Lean modes upon cloning.
- End-to-end acceptance tests guarantee zero regressions across Tuist generation, xcodebuild, and ArchTests.

### BDD SCENARIOS

#### Scenario 4.1: Full Round-Trip Acceptance [Tier C - Integration]
```gherkin
Given the template repository
When the developer switches to "lean" mode via "scripts/configure_mode.sh lean"
Then "tuist generate --no-open" succeeds
And "xcodebuild build" passes
When the developer switches back to "enterprise" mode via "scripts/configure_mode.sh enterprise"
Then "tuist generate --no-open" succeeds
And "xcodebuild build" passes
And "swift test --package-path ArchTests" passes 100%.
```

#### Scenario 4.2: Developer Documentation Accuracy [Tier A - Unit]
```gherkin
Given "README.md" and "docs/architecture/ARCHITECTURE.md"
When a developer consults the Getting Started section
Then clear instructions for initializing in Enterprise Mode or Lean Mode are present
And instructions for "scripts/configure_mode.sh" and "scripts/rename_project.sh --mode" are documented with examples.
```

## Test & Verification Checklist

- [ ] **RED**: Confirm missing documentation sections regarding dual modes.
- [ ] **GREEN**:
  - Run round-trip verification across both modes.
  - Update `README.md` and `docs/architecture/ARCHITECTURE.md`.
- [ ] **REFACTOR**:
  - Format documentation for readability and correct markdown links.
  - Run `quality_check` to ensure repository cleanliness.
- [ ] **Tier C (Integration)**: Final verification on Xcode project builds and ArchTests pass rate.

## Definition of Done (DoD)
- Round-trip switching passes with zero manual intervention.
- All BDD scenarios across all tasks pass.
- `README.md` and architecture documentation updated and reviewed.

## Dependencies & Blockers
- Blocked by [Task 3](task_3_rename_project_mode_integration.md).

## References & Rollback
- Source Spec: [2026-09-14-dual-mode-template-configuration-design.md](2026-09-14-dual-mode-template-configuration-design.md)
- Rollback: `git checkout -- README.md docs/`
