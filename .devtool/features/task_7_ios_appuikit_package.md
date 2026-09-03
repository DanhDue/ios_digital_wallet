---
id: "task_7_ios_appuikit_package"
status: "backlog"
priority: "medium"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["architecture", "spm", "design-system"]
order: "a7"
---

# Task 7: Create `AppUIKit` SPM local package

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Create `Sources/AppUIKit/` — the iOS equivalent of Flutter `packages/ui_kit` and Android `:ui_kit`. Provides the Design System and reusable SwiftUI components shared across all Features. Named `AppUIKit` (not `UIKit`) to avoid collision with Apple's `UIKit` framework.

**Critical invariant**: `AppUIKit` depends on `Core` ONLY — NOT on `Framework`. Design system components do not manage state via `MviViewModel`; they receive data via `@Binding`/`let` and emit actions via closures. This matches the Android invariant (`:ui_kit` does not depend on `:framework`).

**Contents** (template-level, not digital-wallet-specific):

```
Sources/AppUIKit/Sources/AppUIKit/
├── DesignSystem/
│   ├── Color/AppColor.swift           ← semantic color tokens (SwiftUI Color extensions)
│   ├── Typography/AppFont.swift       ← typography scale (Font extensions)
│   ├── Spacing/AppSpacing.swift       ← spacing constants (8pt grid)
│   └── Theme/AppTheme.swift           ← light/dark mode configuration
├── Components/
│   ├── Button/AppButton.swift         ← primary/secondary/destructive variants
│   ├── TextField/AppTextField.swift   ← styled text input
│   ├── LoadingView/AppLoadingView.swift ← loading indicator
│   ├── ErrorView/AppErrorView.swift   ← error state with retry
│   └── EmptyView/AppEmptyStateView.swift
└── Extensions/
    ├── View+Modifiers.swift            ← common SwiftUI view modifiers
    └── Color+Hex.swift
```

All components are purely presentational — no `@StateObject`, no `ObservableObject`. Only `@Binding`, `@State` for local transient UI state (e.g. text field focus), and closures for actions.

## Relevant Files & Context Pointers

- `Sources/AppUIKit/Package.swift` — **NEW** (depends on `Core` only)
- `Sources/AppUIKit/Sources/AppUIKit/` — all files above
- `Sources/AppUIKit/Tests/AppUIKitTests/` — snapshot tests (if XCTest snapshot available) or basic init tests
- `iOSDigitalWallet.xcodeproj` — add `AppUIKit` local package reference
- Reference: `bloc_digital_wallet/packages/ui_kit/lib/` (Flutter — structural mirror)

## Design Rationale

Not depending on `Framework` is architecturally significant: it means the design system can be extracted and reused in any SwiftUI project without pulling in the MVI machinery. Components use closures for callbacks (not Combine publishers) — this keeps them framework-agnostic and easy to preview in Xcode Previews without a ViewModel.

Color/typography tokens are value-type extensions on SwiftUI `Color`/`Font` (e.g. `Color.appPrimary`) — no configuration object or theme environment. Simple and zero-overhead.

TDD adaptation: SwiftUI view testing is limited without a snapshot framework. Unit tests focus on token correctness (color values, spacing values, font names). Component instantiation tests confirm no crash at init.

## TDD Checklist

- [ ] **RED**: `AppColorTests` — `AppColor.primary` returns expected hex; dark mode variant differs from light.
- [ ] **RED**: `AppSpacingTests` — spacing constants (xs=4, sm=8, md=16, lg=24, xl=32) match expected values.
- [ ] **RED**: `AppButtonTests` — `AppButton(title:action:)` initializes without crash; disabled state toggles `isEnabled`.
- [ ] **GREEN**: Implement design tokens + components.
- [ ] **REFACTOR**: Add Xcode Previews to each component. SwiftLint + SwiftFormat clean.

## Definition of Done

- `Sources/AppUIKit/` builds. Unit tests green. App imports `AppUIKit` without error.
- **`AppUIKit/Package.swift` does NOT list `Framework` as a dependency** — verified by reading the file.
- All components have Xcode Previews (visual verification without CI).
- SwiftLint + SwiftFormat clean.

## Dependencies & Blockers

- Blocked by [Task 4](task_4_ios_core_package.md) (depends on `Core`).
- Does NOT depend on [Task 5](task_5_ios_framework_package.md) — intentional.
- Blocks [Task 11](task_11_ios_shell.md) (Shell imports `AppUIKit`), [Task 12](task_12_ios_features_and_routing.md).

## References & Rollback

- Source spec §4.2 (module map — `AppUIKit` does not depend on `Framework`), §4.3 (dependency graph invariant).
- Rollback: remove `Sources/AppUIKit/` + package reference. No other files changed.
