---
id: "task_3_rename_project_mode_integration"
status: "todo"
priority: "high"
assignee: null
epic: "template_modes"
dueDate: null
created: "2026-09-14T04:12:00Z"
modified: "2026-09-14T04:12:00Z"
completedAt: null
labels: ["tooling", "bash", "cli"]
order: "a3"
---

# Task 3: Integrate `--mode` Flag into `scripts/rename_project.sh`

Epic: [template_modes](../epic/template_modes/template_modes.en.md)

## Requirement Analysis
Upgrade `scripts/rename_project.sh` to accept an optional `--mode <enterprise|lean>` flag (defaulting to `enterprise`):
1. **CLI Interface**:
   ```bash
   scripts/rename_project.sh <NewAppName> <new.bundle.id> [--mode <enterprise|lean>] [--force] [--dry-run]
   ```
2. **Execution Steps**:
   - Parse `--mode`, reject unsupported mode strings with usage instructions.
   - Execute identity renames (project name, bundle id, URL scheme, Keychain service).
   - In dry-run mode, print planned mode configuration action without executing.
   - In normal execution, invoke `./scripts/configure_mode.sh "${MODE}"`.
3. **Mode-Differentiated Self-Verification**:
   - For `enterprise` mode:
     - `tuist install && tuist generate --no-open`
     - `xcodebuild build -workspace "${NEW_NAME}.xcworkspace" -scheme "$NEW_NAME" ...`
     - `swift test --package-path ArchTests` (AST architecture gate)
     - `scripts/check_module_boundaries.sh` (Feature isolation gate)
   - For `lean` mode:
     - `tuist install && tuist generate --no-open`
     - `xcodebuild build -workspace "${NEW_NAME}.xcworkspace" -scheme "$NEW_NAME" ...`
     - Skip `ArchTests` and `check_module_boundaries.sh` for fast completion.

## Relevant Files & Context Pointers
- `scripts/rename_project.sh`
- `scripts/configure_mode.sh`
- `Module.swift`
- `Project.swift`
- Reference script: `/Users/danhdueexoictif/AllProjects/digital_wallet/android_digital_wallet/scripts/rename_project.sh`

## Design Rationale
- Preserves 100% backward compatibility: running `./scripts/rename_project.sh MyApp com.example.app` without flags continues to configure and verify in `enterprise` mode.
- Isolates mode switching logic inside `configure_mode.sh` rather than duplicating manifest regexes in `rename_project.sh`.

### BDD SCENARIOS

#### Scenario 3.1: Rename with Default Enterprise Mode [Tier C - Integration]
```gherkin
Given a freshly cloned template repository
When the developer executes:
  """
  ./scripts/rename_project.sh SuperWallet com.acme.superwallet
  """
Then the project name is rewritten to "SuperWallet"
And bundle ID is rewritten to "com.acme.superwallet"
And "scripts/configure_mode.sh enterprise" is executed
And the verification runs "tuist generate", "xcodebuild build", and "swift test --package-path ArchTests"
And the script exits 0.
```

#### Scenario 3.2: Rename with Lean Mode [Tier C - Integration]
```gherkin
Given a freshly cloned template repository
When the developer executes:
  """
  ./scripts/rename_project.sh LeanWallet com.acme.leanwallet --mode lean
  """
Then the project name is rewritten to "LeanWallet"
And bundle ID is rewritten to "com.acme.leanwallet"
And "scripts/configure_mode.sh lean" is executed
And "tuist generate" generates a 2-tab workspace
And "xcodebuild build -scheme LeanWallet" passes
And "ArchTests" execution is skipped
And the script exits 0.
```

#### Scenario 3.3: Dry Run Mode Verification [Tier A - Unit]
```gherkin
Given a template repository
When the developer executes:
  """
  ./scripts/rename_project.sh TestApp com.test.app --mode lean --dry-run
  """
Then it should output "WOULD CONFIGURE MODE: scripts/configure_mode.sh lean"
And no files on disk should be modified
And exit code should be 0.
```

## Test & Verification Checklist

- [ ] **RED**: Run test script validating `--mode` CLI parsing and dry-run output.
- [ ] **GREEN**: Modify `scripts/rename_project.sh` to parse `--mode`, call `configure_mode.sh`, and branch verification based on mode.
- [ ] **REFACTOR**:
  - Check with ShellCheck: `shellcheck scripts/rename_project.sh`.
  - Verify help text and summary output match the new parameters.
- [ ] **Tier C (Integration)**: Perform test run of `rename_project.sh` on dry-run and clean testbed.

## Definition of Done (DoD)
- `scripts/rename_project.sh` successfully parses `--mode <enterprise|lean>`.
- Self-verification is differentiated per mode.
- Dry-run prints accurate planning information.

## Dependencies & Blockers
- Blocked by [Task 2](task_2_configure_mode_script.md).

## References & Rollback
- Reference: Android `scripts/rename_project.sh`
- Rollback: `git checkout -- scripts/rename_project.sh`
