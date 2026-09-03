---
id: "task_7_ios_appuikit_package"
status: "done"
priority: "medium"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: "2026-09-03T15:27:22Z"
labels: ["architecture", "spm", "design-system"]
order: "a7"
---

# Task 7: Create `AppUIKit` SPM package

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: A (behavioral — light).** SwiftUI view coverage is limited without a snapshot lib; scenarios focus on token correctness + no-crash instantiation + accessibility.

## Requirement Analysis

`Packages/AppUIKit/` — depends on `Core` **only**, **never** `Framework` (hard invariant; ArchTests K checks the manifest). Named `AppUIKit` to avoid colliding with Apple's `UIKit`. Purely presentational: `@Binding`, `@State` for local transient UI state, closures for actions. No `ObservableObject`, no `@StateObject`.

```
Sources/AppUIKit/
├── DesignSystem/
│   ├── Color/AppColor.swift        semantic tokens as Color extensions (light + dark)
│   ├── Typography/AppFont.swift    type scale
│   ├── Spacing/AppSpacing.swift    xs=4 sm=8 md=16 lg=24 xl=32
│   └── Theme/AppTheme.swift        light/dark config
├── Components/
│   ├── Button/AppButton.swift          primary / secondary / destructive; disabled + loading states
│   ├── TextField/AppTextField.swift
│   ├── State/AppLoadingView.swift
│   ├── State/AppErrorView.swift        message + retry closure
│   └── State/AppEmptyStateView.swift
└── Extensions/
    ├── View+Modifiers.swift
    └── Color+Hex.swift
```

## Relevant Files & Context Pointers

- `Packages/AppUIKit/Package.swift`, `Packages/AppUIKit/Sources/AppUIKit/**`, `Packages/AppUIKit/Tests/AppUIKitTests/**` — **NEW**
- `Tuist/Package.swift` — marker-region entry for `Packages/AppUIKit`
- Source Spec §4.2 (`AppUIKit` does NOT depend on `Framework`), §4.3 invariant

## Design Rationale

Not depending on `Framework` means the design system is extractable into any SwiftUI project without the MVI machinery, and components preview in Xcode with no ViewModel. Tokens are value-type extensions (`Color.appPrimary`, `AppSpacing.md`) — zero-overhead, no theme environment object.

**Applicable skills:** check `.agents/skills/` for a `mobile-uiux` / design-system skill; note it here if present.

### BDD Scenarios

```gherkin
# Happy path / token correctness (boundary + equivalence)
Scenario Outline: spacing constants have the exact 8pt-grid values
  Then AppSpacing.<name> == <value>
  Examples: | name | value | (xs,4) (sm,8) (md,16) (lg,24) (xl,32)

Scenario: AppColor.primary resolves to the documented hex in light mode
Scenario: AppColor.primary resolves to a different hex in dark mode
Scenario: Color(hex:) parses "#RRGGBB", "RRGGBB", and "#RGB"; returns nil for "xyz"

# State transitions
Scenario: AppButton(loading: true) shows a spinner and ignores taps
Scenario: AppButton(enabled: false) renders the disabled style and ignores taps
Scenario: AppButton tap invokes the action closure exactly once

# Failure / edge
Scenario: AppErrorView with a nil retry closure hides the retry button
Scenario: AppTextField with an empty binding shows the placeholder
Scenario: AppEmptyStateView renders with a very long title without truncation crash

# Accessibility
Scenario: AppButton exposes its title as the accessibility label
Scenario: AppLoadingView is marked as an accessibility element with "Loading" label

# Resource teardown — n/a (value types / no subscriptions)
```

### TDD Tests

- `AppSpacingTests`, `AppColorTests` — exact values; light vs dark differ; `Color(hex:)` parse matrix incl. the nil case.
- `AppButtonTests` — init without crash; tap fires action once; `loading`/`disabled` suppress the action (drive via a test closure counter; host in `UIHostingController` for the render path).
- `AppErrorViewTests` — retry closure nil → no retry affordance (inspect via `ViewInspector` if added, else assert the view builds and the closure is `nil`).
- `AccessibilityTests` — assert `.accessibilityLabel` values.

### RED → GREEN

- RED: token tests fail (constants absent); component tests fail to compile.
- GREEN: implement tokens then components; keep every component free of `ObservableObject`.

## Definition of Done

- `swift test --package-path Packages/AppUIKit` green; every scenario has a passing test.
- **`Package.swift` does NOT list `Framework`** — verified by reading the file and by ArchTests (Task 9).
- Every component has an Xcode Preview.
- SwiftLint/SwiftFormat clean. Coverage ≥ 70% (token + logic paths).

## Dependencies & Blockers

- Blocked by [Task 4](task_4_ios_core_package.md). Does **not** depend on [Task 5](task_5_ios_framework_package.md) — intentional.
- Blocks [Task 10](task_10_ios_shell.md), [Task 11](task_11_ios_settings_feature.md), [Task 12](task_12_ios_scanner_and_composition.md).

## References & Rollback

- Source Spec §4.2, §4.3.
- Rollback: remove `Packages/AppUIKit/` + marker line.
