# BDD Scenarios: Dual-Mode iOS Native Template (Enterprise vs Lean Mode)

## Overview
This document contains the canonical Behavior-Driven Development (BDD) test suite for the `template_modes` epic on the iOS Native Template.

---

### Feature: Mode Configuration (`scripts/configure_mode.sh`)

#### Scenario 1: Transition from Enterprise to Lean Mode [Tier A - Unit]
```gherkin
Given the repository is currently configured in "enterprise" mode
And "Tuist/Package.swift" includes ".package(path: \"../Features/Scanner\")"
And "Project.swift" includes ".external(name: \"Scanner\")"
And "App/Sources/Composition/AppComposition.swift" imports "Scanner"
And "Packages/Shell/Sources/Shell/ShellView.swift" contains the Scanner tab item
When the developer runs "./scripts/configure_mode.sh lean"
Then the script should exit with status 0
And "Tuist/Package.swift" should have ".package(path: \"../Features/Scanner\")" commented out
And "Project.swift" should have ".external(name: \"Scanner\")" commented out
And "App/Sources/Composition/AppComposition.swift" should have "import Scanner" commented out
And "App/Sources/Composition/AppComposition.swift" should have "scannerProvider" registration commented out
And "App/Sources/Composition/AppComposition.swift" should configure "ShellConfig(tabCount: 2, initialTab: 1)"
And "Packages/Shell/Sources/Shell/ShellView.swift" should have the Scanner tab block commented out
And Tuist project generation should succeed
```

#### Scenario 2: Transition from Lean back to Enterprise Mode (Idempotency) [Tier A - Unit]
```gherkin
Given the repository is currently configured in "lean" mode with Scanner commented out
When the developer runs "./scripts/configure_mode.sh enterprise"
Then the script should exit with status 0
And "Tuist/Package.swift" should have ".package(path: \"../Features/Scanner\")" uncommented
And "Project.swift" should have ".external(name: \"Scanner\")" uncommented
And "App/Sources/Composition/AppComposition.swift" should have "import Scanner" uncommented
And "App/Sources/Composition/AppComposition.swift" should have "scannerProvider" registration uncommented
And "App/Sources/Composition/AppComposition.swift" should configure "ShellConfig(tabCount: 3, initialTab: 2)"
And "Packages/Shell/Sources/Shell/ShellView.swift" should have the Scanner tab block uncommented
And Tuist project generation should succeed
```

#### Scenario 3: Physical Prune on Clean Tree [Tier A - Unit]
```gherkin
Given the repository has a clean git working tree
And directory "Features/Scanner" exists on disk
When the developer runs "./scripts/configure_mode.sh lean --prune"
Then the script should exit with status 0
And directory "Features/Scanner" should no longer exist on disk
And Tuist project generation should succeed without references to "Features/Scanner"
```

#### Scenario 4: Physical Prune Blocked on Dirty Tree [Tier A - Unit]
```gherkin
Given the repository has uncommitted changes in the git working tree
When the developer runs "./scripts/configure_mode.sh lean --prune" without "--force"
Then the script should exit with a non-zero error code
And an error message stating "git working tree is dirty" should be displayed
And directory "Features/Scanner" should NOT be deleted
```

#### Scenario 5: Physical Prune Allowed on Dirty Tree with Force [Tier A - Unit]
```gherkin
Given the repository has uncommitted changes in the git working tree
When the developer runs "./scripts/configure_mode.sh lean --prune --force"
Then the script should proceed without error
And directory "Features/Scanner" should be removed from disk
```

---

### Feature: Project Rename Integration (`scripts/rename_project.sh`)

#### Scenario 6: Renaming Project with Default Enterprise Mode [Tier C - Integration]
```gherkin
Given a freshly cloned template repository
When the developer executes "./scripts/rename_project.sh SuperApp com.enterprise.superapp"
Then the project should be renamed to "SuperApp" with bundle ID "com.enterprise.superapp"
And the mode configuration should default to "enterprise"
And "Tuist/Package.swift" should include active dependencies for both "Settings" and "Scanner"
And the self-verification step should execute:
  | Command |
  | tuist install |
  | tuist generate --no-open |
  | xcodebuild build -scheme SuperApp |
  | swift test --package-path ArchTests |
  | scripts/check_module_boundaries.sh |
And the script should exit with status 0
```

#### Scenario 7: Renaming Project with Lean Mode [Tier C - Integration]
```gherkin
Given a freshly cloned template repository
When the developer executes "./scripts/rename_project.sh LiteApp com.startup.liteapp --mode lean"
Then the project should be renamed to "LiteApp" with bundle ID "com.startup.liteapp"
And "scripts/configure_mode.sh lean" should be invoked automatically
And "Scanner" dependencies should be commented out
And the self-verification step should execute:
  | Command |
  | tuist install |
  | tuist generate --no-open |
  | xcodebuild build -scheme LiteApp |
And the self-verification step should explicitly SKIP:
  | Command |
  | swift test --package-path ArchTests |
And the script should exit with status 0 with fast build time
```

#### Scenario 8: Renaming Project with Invalid Mode Flag [Tier A - Unit]
```gherkin
Given a template repository
When the developer executes "./scripts/rename_project.sh LiteApp com.startup.liteapp --mode invalid_mode"
Then the script should abort immediately before making any file modifications
And an error message "unknown mode 'invalid_mode'. Valid modes are: enterprise, lean" should be output
And the script should exit with a non-zero status code
```
