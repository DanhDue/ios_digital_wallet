---
id: "task_1_ios_quality_tooling"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["tooling", "quality", "foundation"]
order: "a1"
---

# Task 1: SwiftLint + SwiftFormat quality tooling setup

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Establish the code quality gate for the entire iOS template — the iOS equivalent of `buildSrc` convention plugins (Android) or the `codeanalyzetools` Gradle plugins. Every Swift file in the project — both infra packages and Feature files — must pass these checks before merge.

Two tools:
- **SwiftLint**: enforces style rules + custom architectural rules (layer enforcement, naming conventions). Custom rules are the equivalent of Konsist rules K2/K3/K4/K5 for Android.
- **SwiftFormat**: enforces consistent formatting (indentation, imports, trailing commas, etc.).

Shared config files live in `quality/` at the repo root so all SPM packages and the app target reference the same ruleset via `--config` path.

**Custom SwiftLint rules to implement** (architectural enforcement):
- `no_ui_in_domain`: Domain files cannot `import UIKit`, `SwiftUI`, or `Combine` (K3 equivalent).
- `no_public_in_data`: Data layer files cannot declare `public` types (K4 equivalent).
- `viewmodel_naming`: ViewModel files must subclass `MviViewModel` or `MvvmViewModel` (K5 partial).
- `route_must_be_in_platform`: `AppRoute`-conforming structs in `Features/` that are used cross-feature must live in `Platform/AppRoutes.swift` (K9 equivalent — warning only, Phase 1+).

**Xcode Build Phase integration**: Add a Run Script Build Phase to the main app scheme that runs SwiftLint (`--config quality/.swiftlint.yml`) so violations surface inline in Xcode during development, not only in CI.

## Relevant Files & Context Pointers

- `quality/.swiftlint.yml` — **NEW**: shared SwiftLint config
- `quality/.swiftformat` — **NEW**: shared SwiftFormat config
- `iOSDigitalWallet.xcodeproj` — add Run Script Build Phase for SwiftLint
- Reference: `.devtool/epic/android_super_app_template/2026-09-02-android-super-app-template-design.md` §6.1 (Konsist rules K2–K9, analogues to implement here)
- Reference: `.devtool/epic/flutter_super_app_template/2026-08-29-flutter-super-app-template-design.md` §3.5 (SwiftLint/SwiftFormat decision)
- Reference: `android_digital_wallet/buildSrc/src/main/kotlin/codeanalyzetools/` (Android quality convention plugins — read for parity)

## Design Rationale

The `quality/` directory at repo root mirrors Flutter's `ios/quality/` location decided in `flutter_super_app_template`. Placing config at repo root (not inside each SPM package) allows a single `--config` path to serve both the app target and future SPM local packages — no duplication.

Custom rules use SwiftLint's `custom_rules` (regex-based). They are weaker than Konsist (which reads AST), but sufficient for the naming/import checks needed here. The boundary check (cross-feature import) is handled by the separate shell script in Task 2 — these two complement each other.

TDD adaptation: This task creates config files and a build phase script, not testable behavior. Replace RED/GREEN/REFACTOR with verification steps below.

## TDD Checklist

TDD adapted — no new runtime behavior; this task is pure config + tooling setup.

- [ ] **CONFIG**: Write `quality/.swiftlint.yml` with base rules + 4 custom rules above. Run `swiftlint --config quality/.swiftlint.yml` against existing `iOSDigitalWallet/` — expect zero violations on the base Hello World files.
- [ ] **CONFIG**: Write `quality/.swiftformat` with agreed settings (indent 4, maxwidth 120, importgrouping testable-last, etc.). Run `swiftformat --config quality/.swiftformat iOSDigitalWallet/ --lint` — expect zero violations.
- [ ] **INTEGRATE**: Add Run Script Build Phase to `iOSDigitalWallet` scheme: `if which swiftlint > /dev/null; then swiftlint --config "${SRCROOT}/../quality/.swiftlint.yml"; fi`. Build the scheme in Xcode — confirm no error.
- [ ] **VERIFY**: Introduce an intentional violation (e.g. add `import SwiftUI` to a file named `*Domain*`) → confirm SwiftLint flags it → revert.
- [ ] **VERIFY**: Run `swiftformat --config quality/.swiftformat . --lint` from repo root — exits 0.

## Definition of Done

- `quality/.swiftlint.yml` and `quality/.swiftformat` exist at repo root.
- All 4 custom rules defined and verified (intentional violation test passed).
- Xcode Build Phase runs SwiftLint on `iOSDigitalWallet/` with zero violations on current Hello World codebase.
- `swiftformat --lint` exits 0 on current codebase.
- Both files committed; ready for Task 2 to add them to CI pipeline.

## Dependencies & Blockers

- Not blocked by any task.
- Blocks [Task 2](task_2_ios_boundary_ci.md) (CI needs both tools configured before adding them to workflow).
- Blocks [Task 4](task_4_ios_core_package.md) (all SPM packages must pass these quality checks from day one).

## References & Rollback

- Source spec §9.1 (SwiftLint custom rules), §9.2 (SwiftFormat config).
- SwiftLint custom_rules docs: https://realm.github.io/SwiftLint/custom-rules.html
- Rollback: delete `quality/` directory and remove the Xcode Build Phase script. No other files are changed.
