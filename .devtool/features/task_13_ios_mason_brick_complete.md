---
id: "task_13_ios_mason_brick_complete"
status: "backlog"
priority: "medium"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["mason", "tooling", "template"]
order: "a13"
---

# Task 13: Complete `ios_mvi_feature` brick with post_gen checklist

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Complete the `bricks/ios_mvi_feature/` Mason brick from Task 3 by adding `hooks/post_gen.dart`. The hook prints a **manual checklist** to the terminal after file generation — it does NOT auto-mutate `.pbxproj` (see spec §14 risk rationale).

**Checklist items to print** (after `mason make ios_mvi_feature --name {Name}`):

```
✅ Files generated: Features/{Name}/Data, Domain, Presentation

📋 Manual steps required:
  1. In Xcode Project Navigator: drag the Features/{Name}/ folder into the project
     and ensure all .swift files are added to the 'iOSDigitalWallet' target.
  2. In iOSDigitalWallet/App/iOSDigitalWalletApp.swift:
     - Import and instantiate {Name}ViewModel (with dependencies)
     - Register {Name}RouteProvider with appRouter.register(...)
  3. If this Feature has a cross-feature route (used from other Features):
     - Add `public struct {Name}Route: AppRoute {}` to Sources/Platform/Sources/Platform/Navigation/AppRoutes.swift
  4. Run `scripts/check_module_boundaries.sh` to confirm no cross-Feature imports.
  5. Run `xcodebuild build -scheme iOSDigitalWallet` to confirm everything compiles.
```

Also update `__brick__/` templates to reference the real `Settings` Feature implementation (from Task 12) as inline comments showing the complete example:
- Generated `{Name}RepositoryImpl.swift` has a `// See: Settings/Data/Repository/SettingsRepositoryImpl.swift` comment
- Generated `{Name}ViewModel.swift` has `// See: Settings/Presentation/SettingsViewModel.swift` comment

## Relevant Files & Context Pointers

- `bricks/ios_mvi_feature/hooks/post_gen.dart` — **NEW**
- `bricks/ios_mvi_feature/__brick__/` — UPDATE templates with cross-reference comments
- Reference: `bricks/pac_mvi_feature/hooks/post_gen.dart` in `bloc_digital_wallet` (Flutter — mirror pattern)
- Reference: Task 3 (scaffold basis)
- Source spec §10 (brick definition, `post_gen.dart` rationale)

## Design Rationale

TDD adaptation: `post_gen.dart` is a Dart script that prints text — no meaningful unit test surface. Verification is running `mason make` and inspecting stdout.

The decision NOT to auto-mutate `.pbxproj` is architectural: Xcode project files are complex XML-binary hybrids that are easily corrupted by text substitution. The manual checklist approach trades automation for safety — a corrupt `.pbxproj` blocks the entire team and is harder to debug than a checklist.

## TDD Checklist

TDD adapted — Dart hook script, no runtime behavior.

- [ ] **WRITE**: `hooks/post_gen.dart` with the 5-step checklist output.
- [ ] **VERIFY**: `mason make ios_mvi_feature --name Payments` → stdout shows the checklist with `Payments` substituted correctly.
- [ ] **VERIFY**: `mason make ios_mvi_feature --name Scanner` → stdout shows `Scanner` in checklist items.
- [ ] **VERIFY**: Generated files in `Features/Payments/` contain cross-reference comments pointing to Settings.
- [ ] **CLEANUP**: Remove generated test output before committing.

## Definition of Done

- `bricks/ios_mvi_feature/hooks/post_gen.dart` exists and prints correct checklist.
- Feature name substituted in all checklist items.
- Cross-reference comments in generated templates point to Settings implementation.
- `mason make ios_mvi_feature --name X` end-to-end: files generated + checklist printed + generated files pass SwiftLint.

## Dependencies & Blockers

- Blocked by [Task 3](task_3_ios_mason_brick_scaffold.md) (scaffold must exist).
- Blocked by [Task 12](task_12_ios_features_and_routing.md) (cross-reference comments point to Settings implementation).

## References & Rollback

- Source spec §10 (brick + post_gen rationale).
- Rollback: delete `hooks/post_gen.dart`. Brick still works (Task 3 scaffold), just without checklist.
