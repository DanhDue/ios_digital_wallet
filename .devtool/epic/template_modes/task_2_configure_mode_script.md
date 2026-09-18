---
id: "task_2_configure_mode_script"
status: "todo"
priority: "high"
assignee: null
epic: "template_modes"
dueDate: null
created: "2026-09-14T04:11:45Z"
modified: "2026-09-14T04:11:45Z"
completedAt: null
labels: ["tooling", "bash", "automation"]
order: "a2"
---

# Task 2: Implement `scripts/configure_mode.sh` Script

Epic: [template_modes](template_modes.en.md)

## Requirement Analysis
Create a robust, idempotent Bash script at `scripts/configure_mode.sh` capable of toggling the iOS template between `enterprise` and `lean` modes:
1. Support syntax:
   ```bash
   scripts/configure_mode.sh <enterprise|lean> [--prune] [--force] [--root-dir=<path>]
   ```
2. For `enterprise` mode:
   - Uncomment `.package(path: "../Features/Scanner"),` in `Tuist/Package.swift`.
   - Uncomment `.external(name: "Scanner"),` in `Project.swift`.
   - Uncomment `import Scanner` and `scannerProvider` in `App/Sources/Composition/AppComposition.swift`.
   - Uncomment Scanner tab in `Packages/Shell/Sources/Shell/ShellView.swift`.
   - Set `ShellConfig(tabCount: 3, initialTab: 2)` in `AppComposition.swift`.
3. For `lean` mode:
   - Comment out `.package(path: "../Features/Scanner"),` in `Tuist/Package.swift`.
   - Comment out `.external(name: "Scanner"),` in `Project.swift`.
   - Comment out `import Scanner` and `scannerProvider` in `App/Sources/Composition/AppComposition.swift`.
   - Comment out Scanner tab in `Packages/Shell/Sources/Shell/ShellView.swift`.
   - Set `ShellConfig(tabCount: 2, initialTab: 1)` in `AppComposition.swift`.
4. Run `tuist install` and `tuist generate --no-open` after patching.
5. Handle `--prune`:
   - If git working tree is dirty and `--force` is absent, abort with exit code 1.
   - If clean, remove `Features/Scanner/` for `lean` mode.
   - For `enterprise` mode, prune is a no-op.

## Relevant Files & Context Pointers
- `scripts/configure_mode.sh` (new)
- `Tuist/Package.swift`
- `Project.swift`
- `App/Sources/Composition/AppComposition.swift`
- `Packages/Shell/Sources/Shell/ShellView.swift`
- `App/Sources/Composition/DeepLinkComposition.swift`
- Reference script: `/Users/danhdueexoictif/AllProjects/digital_wallet/android_digital_wallet/scripts/configure_mode.sh`

## Design Rationale
- Uses in-place `perl` regex replacements with `\Q...\E` escaping to avoid delimiter collision and guarantee idempotency.
- Never duplicates lines or removes markers on repeated runs.
- Provides `--root-dir` parameter to enable unit testing the script against temporary mock workspace fixtures without altering the main project tree.

### BDD SCENARIOS

#### Scenario 2.1: Idempotent Lean Mode Configuration [Tier A - Unit]
```gherkin
Given a project in default "enterprise" mode
When the developer runs "scripts/configure_mode.sh lean"
Then Scanner package references in "Tuist/Package.swift" and "Project.swift" are commented out
And "App/Sources/Composition/AppComposition.swift" has Scanner imports commented out
And running "scripts/configure_mode.sh lean" a second time produces identical output with zero corruptions
And "tuist generate --no-open" succeeds.
```

#### Scenario 2.2: Idempotent Enterprise Mode Configuration [Tier A - Unit]
```gherkin
Given a project currently in "lean" mode
When the developer runs "scripts/configure_mode.sh enterprise"
Then all Scanner references across manifests, composition, and ShellView are restored
And "tuist generate --no-open" succeeds
And the workspace contains all 8 packages and 2 features.
```

#### Scenario 2.3: Safe Prune Guard [Tier A - Unit]
```gherkin
Given a project in git with uncommitted dirty changes
When the developer runs "scripts/configure_mode.sh lean --prune"
Then the script must print "error: git working tree is dirty. Refusing to --prune without --force."
And exit with code 1
And "Features/Scanner" must NOT be deleted.
```

#### Scenario 2.4: Forced Prune on Dirty Tree [Tier A - Unit]
```gherkin
Given a project in git with uncommitted changes
When the developer runs "scripts/configure_mode.sh lean --prune --force"
Then the script must proceed
And delete "Features/Scanner" from disk
And "tuist generate --no-open" succeeds without errors.
```

## Test & Verification Checklist

- [ ] **RED**: Write a test script in `scripts/tests/test_configure_mode.sh` asserting failure for invalid arguments, dirty-tree prune guard, and manifest transformations.
- [ ] **GREEN**: Implement `scripts/configure_mode.sh` with argument parsing, perl regex replacement helpers, Tuist synchronization, and prune handling.
- [ ] **REFACTOR**:
  - Run ShellCheck: `shellcheck scripts/configure_mode.sh`.
  - Ensure executable permissions: `chmod +x scripts/configure_mode.sh`.
  - Validate against test runner: `bash scripts/tests/test_configure_mode.sh`.
- [ ] **Tier C (Integration)**: Verify `xcodebuild build` succeeds in both `enterprise` and `lean` modes.

## Definition of Done (DoD)
- `scripts/configure_mode.sh` created, passing ShellCheck, and verified executable.
- Switching back and forth between `enterprise` and `lean` produces clean, compiling code with zero warnings.
- Prune guard verified against dirty working trees.

## Dependencies & Blockers
- Blocked by [Task 1](task_1_standardize_marker_regions.md).

## References & Rollback
- Reference: Android `scripts/configure_mode.sh`
- Rollback: `rm -f scripts/configure_mode.sh && git checkout -- .`
