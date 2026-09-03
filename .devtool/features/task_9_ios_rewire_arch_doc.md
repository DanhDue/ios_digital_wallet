---
id: "task_9_ios_rewire_arch_doc"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["architecture", "docs", "refactor"]
order: "a9"
---

# Task 9: Rewire app target + enable layer rules + ARCHITECTURE.md

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Integration task that closes Phase 1:

1. **Rewire app target**: `iOSDigitalWalletApp.swift` imports all 5 SPM packages (`Core`, `Framework`, `Network`, `AppUIKit`, `Platform`). Delete `ContentView.swift`. Add a temporary placeholder `ContentView` that just shows `Text("Template — Phase 1 complete")` so the app builds.

2. **Enable SwiftLint layer rules**: Upgrade `quality/.swiftlint.yml` — turn custom rules from `warning` to `error` severity where applicable (K3 `no_ui_in_domain`, K4 `no_public_in_data`). Add to CI: `swiftlint --strict`.

3. **Write `docs/architecture/ARCHITECTURE.md` (iOS variant)**: Same section structure as Flutter's `ARCHITECTURE.md`. Covers: Layer model (`Presentation → Domain ← Data`), SPM module map (5 packages), dependency graph, MVI pattern (Action/State/Event), naming conventions, navigation pattern (`AppRouter`/`RouteProvider`), event bus, iOS-specific notes (NavigationPath iOS 16 gap, Combine vs @Observable decision, SPM-only decision). This doc is the onboarding reference for new iOS developers.

4. **Verify `xcodebuild build` + `xcodebuild test` pass end-to-end** with all 5 packages linked.

## Relevant Files & Context Pointers

- `iOSDigitalWallet/iOSDigitalWalletApp.swift` — rewire imports
- `iOSDigitalWallet/ContentView.swift` — replace with placeholder
- `quality/.swiftlint.yml` — upgrade severities
- `docs/architecture/ARCHITECTURE.md` — **NEW** (iOS variant)
- All 5 `Sources/*/Package.swift` — verify they resolve correctly together
- Reference: `bloc_digital_wallet/docs/architecture/ARCHITECTURE.md` (Flutter — mirror section structure)
- Reference: `.devtool/epic/android_super_app_template/` Task 9 (Android ARCHITECTURE.md — same phase)

## Design Rationale

TDD adaptation: this task is a wiring/integration + documentation task. The verification is `xcodebuild` success and SwiftLint strictness escalation. No new behavioral code to TDD.

Writing `ARCHITECTURE.md` now (end of Phase 1) rather than at the end of the epic ensures: (a) new developers can onboard mid-epic, (b) the document matches the actual implemented packages rather than planned spec, (c) Phase 2 implementers have a reference while building Shell/Features.

## TDD Checklist

TDD adapted — integration + documentation task.

- [ ] **REWIRE**: Update `iOSDigitalWalletApp.swift` with all 5 imports. Run `xcodebuild build` — zero errors.
- [ ] **VERIFY**: Run `xcodebuild test -scheme iOSDigitalWallet` — all unit tests from Tasks 4–8 pass.
- [ ] **ESCALATE**: Update SwiftLint severities to `error`. Run `swiftlint --strict --config quality/.swiftlint.yml` on all `Sources/*/` — zero errors (new packages must be clean).
- [ ] **DOCUMENT**: Write `docs/architecture/ARCHITECTURE.md` covering all sections. Peer-review: does a developer unfamiliar with the repo understand the layer model and how to add a new Feature after reading this doc?
- [ ] **CI**: Confirm GitHub Actions CI remains green after these changes (new `--strict` SwiftLint flag propagated to workflow).

## Definition of Done

- `xcodebuild build` and `xcodebuild test` green with all 5 packages.
- `swiftlint --strict` exits 0 on all `Sources/*/`.
- `docs/architecture/ARCHITECTURE.md` written, committed, reviewed.
- CI green on `develop`.

## Dependencies & Blockers

- Blocked by [Task 8](task_8_ios_platform_package.md) (all 5 packages must exist).
- Blocks [Task 10](task_10_ios_app_structure.md) (Phase 2 starts here).

## References & Rollback

- Source spec §3 (principles), §4.1–4.4 (architecture).
- Rollback: revert `iOSDigitalWalletApp.swift` + `quality/.swiftlint.yml` severity changes. `ARCHITECTURE.md` stays (no harm leaving a doc).
