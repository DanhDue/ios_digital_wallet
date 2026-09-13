---
id: "task_1_standardize_marker_regions"
status: "todo"
priority: "high"
assignee: null
epic: "template_modes"
dueDate: null
created: "2026-09-14T04:11:30Z"
modified: "2026-09-14T04:11:30Z"
completedAt: null
labels: ["architecture", "tooling", "shell"]
order: "a1"
---

# Task 1: Standardize Marker Regions in ShellView & AppComposition

Epic: [template_modes](../epic/template_modes/template_modes.en.md)

## Requirement Analysis
To enable clean, idempotent, and non-destructive mode toggling between `enterprise` and `lean` without requiring fragile AST transformers or complex code generators, all points of variation must be enclosed in predictable comment markers:
1. In `Packages/Shell/Sources/Shell/ShellView.swift`:
   - The Scanner tab block must be enclosed within `// shell:scanner-tab:begin` and `// shell:scanner-tab:end`.
   - Settings tab index and tag must support dynamic or configurable index alignment so that when Scanner is disabled, the layout cleanly renders as 2 tabs (Tab 0: Home, Tab 1: Settings) without an empty intermediate tab.
2. In `App/Sources/Composition/AppComposition.swift`:
   - Ensure `ShellConfig` initialization is marked or configurable for `tabCount` and `initialTab` (3 tabs for Enterprise, 2 tabs for Lean).
3. In `App/Sources/Composition/DeepLinkComposition.swift`:
   - Ensure `ShellTabResolver` has marker comments around `AppRoutes.ScannerRoot` resolution (`// app:tab-resolver-scanner:begin/end`) so Lean mode does not route to an absent tab index.

## Relevant Files & Context Pointers
- `Packages/Shell/Sources/Shell/ShellView.swift`
- `Packages/Shell/Sources/Shell/ShellConfig.swift`
- `App/Sources/Composition/AppComposition.swift`
- `App/Sources/Composition/DeepLinkComposition.swift`
- `App/Tests/AppTests/AppCompositionTests.swift`
- `Packages/Platform/Sources/Platform/Navigation/AppRouter.swift`

## Design Rationale
- **Direct String / Regex Operability**: By enclosing dynamic sections in explicit begin/end markers, shell scripts (`configure_mode.sh`) can comment or uncomment blocks in one regex pass without corrupting adjacent Swift code.
- **Architectural Purity**: `ShellView` remains feature-blind. It does not import `Scanner`, it only renders the tab bound to `AppRoutes.ScannerRoot()`.
- **Applicable Skills**:
  - `ios-ui-audit`: Ensure SwiftUI layout and body evaluation remain optimal.
  - `ArchTests`: Ensure K1-K10 rules pass cleanly after adding markers.

### BDD SCENARIOS

#### Scenario 1.1: Scanner Tab Isolation in ShellView [Tier A - Unit]
```gherkin
Given "Packages/Shell/Sources/Shell/ShellView.swift"
When the developer inspects the TabView body
Then the Scanner tabStack block must be clearly enclosed within:
  """
  // shell:scanner-tab:begin
  ...
  // shell:scanner-tab:end
  """
And commenting out the lines within that marker must leave a valid SwiftUI TabView containing Home and Settings.
```

#### Scenario 1.2: ShellConfig Tab Count and Initial Selection [Tier A - Unit]
```gherkin
Given "App/Sources/Composition/AppComposition.swift"
When initialized with "ShellConfig(tabCount: 2, initialTab: 1)"
Then "router.tabPaths.count" must equal 2
And "router.selectedTab" must default to 1 (Settings)
And the Shell must render without out-of-bounds index exceptions.
```

#### Scenario 1.3: DeepLink Tab Placement Resolution [Tier A - Unit]
```gherkin
Given "App/Sources/Composition/DeepLinkComposition.swift"
When "ShellTabResolver" resolves "AppRoutes.SettingsRoot"
Then it must return the configured tab index for Settings
And resolving "AppRoutes.ScannerRoot" when Scanner markers are commented must return nil.
```

## Test & Verification Checklist

- [ ] **RED**: Run tests verifying that existing `AppCompositionTests` and `ShellView` render properly with current 3-tab layout.
- [ ] **GREEN**: Add `// shell:scanner-tab:begin/end` markers in `ShellView.swift`. Update `ShellConfig` and `ShellTabResolver` to support both 3-tab and 2-tab configurations.
- [ ] **REFACTOR**:
  - Format code using `swiftformat --config quality/.swiftformat .`.
  - Lint with `swiftlint lint --strict --config quality/.swiftlint.yml`.
  - Verify boundary checks: `bash scripts/check_module_boundaries.sh`.
  - Run architecture tests: `swift test --package-path ArchTests`.
- [ ] **Tier C (Integration)**: Build the Xcode project using `tuist generate --no-open` to confirm clean compilation.

## Definition of Done (DoD)
- Markers are placed and tested in `ShellView.swift`, `AppComposition.swift`, and `DeepLinkComposition.swift`.
- Code compiles without warnings under Xcode / Tuist.
- All existing unit and architecture tests pass.

## Dependencies & Blockers
- None. This is the foundational task for the Epic.

## References & Rollback
- Source Spec: [2026-09-14-dual-mode-template-configuration-design.md](../epic/template_modes/2026-09-14-dual-mode-template-configuration-design.md)
- Rollback: `git checkout -- Packages/Shell/ App/Sources/Composition/`
