---
id: "task_1_ios_tuist_bootstrap"
status: "todo"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: null
labels: ["tooling", "tuist", "foundation"]
order: "a1"
---

# Task 1: Tuist bootstrap + generated-project gitignore

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: B (tooling / config).** No runtime behavior — verified by a Verification Scenarios table (see Source Spec §9A).

## Requirement Analysis

Stand up Tuist as the declarative project definition for the whole template — the iOS analogue of Android's `settings.gradle.kts` + convention plugins. After this task the `.xcodeproj`/`.xcworkspace` are **generated, never committed**; the repo's source of truth is the Tuist manifests.

Deliverables:
- `Tuist.swift` (or `Tuist/Config.swift`) — Tuist config.
- `mise.toml` **and** `.tuist-version` — pin the exact Tuist version; document in README (Task 3).
- `Tuist/Package.swift` — declares local packages via `.package(path:)`, wrapped in marker regions:
  ```swift
  // tuist:packages:begin
  // tuist:packages:end
  ```
  (empty for now; packages land in Phase 1+). Also `// tuist:app-deps:begin/end` markers wherever the App target's product dependency list will be edited by Mason bricks.
- `Tuist/ProjectDescriptionHelpers/Module.swift` — a shared target factory (`Module.package(name:dependencies:)`, `Module.appTarget(...)`) so every module/target is defined the same way (DRY, deployment target iOS 16 in one place).
- `Project.swift` — the **thin App project**: one app target `iOSDigitalWallet` (bundle id `com.danhdue.iOSDigitalWallet`), deployment target **iOS 16.0**, `App/Sources/**`, `App/Resources/Assets.xcassets`, `App/Resources/Info.plist`. No package deps yet.
- `Workspace.swift` — the App project + (later) the local packages.
- Move `iOSDigitalWallet/iOSDigitalWalletApp.swift` → `App/Sources/iOSDigitalWalletApp.swift`; replace `ContentView.swift` with `App/Sources/RootView.swift` showing `Text("iOS Super App Template — skeleton")`. Move `Assets.xcassets` → `App/Resources/`.
- `.gitignore` — add `*.xcodeproj/`, `*.xcworkspace/`, `.tuist/`, `Derived/`.

## Relevant Files & Context Pointers

- `Tuist.swift`, `Tuist/Package.swift`, `Tuist/ProjectDescriptionHelpers/Module.swift` — **NEW**
- `Project.swift`, `Workspace.swift` — **NEW**
- `mise.toml`, `.tuist-version` — **NEW**
- `App/Sources/iOSDigitalWalletApp.swift`, `App/Sources/RootView.swift` — **NEW** (moved / replaced)
- `App/Resources/Assets.xcassets`, `App/Resources/Info.plist` — moved
- `iOSDigitalWallet/iOSDigitalWalletApp.swift`, `iOSDigitalWallet/ContentView.swift`, `iOSDigitalWallet.xcodeproj/` — **DELETE** (old hand-managed project)
- `.gitignore` — update
- Source Spec §4.1 (folder structure), §13 (`.xcodeproj` not committed), Changelog #2

## Design Rationale

Tuist is chosen over XcodeGen (Q&A) because the template is heavily modular (8 packages + app) and Tuist's graph + `tuist edit` + manifest DSL make Mason-brick auto-wiring safe and reviewable. All version pinning goes through `mise` so CI and every dev machine resolve the same Tuist.

Marker regions in `Tuist/Package.swift` / `Project.swift` are the contract the Mason bricks (Task 13) edit against — line-oriented inserts inside `// tuist:*:begin/end`, never free-form `.pbxproj` mutation.

**Applicable skills:** none specific; this is infra setup.

## Test Plan (Tier B — Verification Scenarios)

TDD adapted: config/tooling task, no runtime behavior. Replace RED/GREEN/REFACTOR with:

| # | Scenario (input) | Expected |
|---|---|---|
| 1 | `mise install` then `tuist --version` | prints the exact version in `.tuist-version` |
| 2 | `tuist generate --no-open` on a clean checkout | exits 0; produces `iOSDigitalWallet.xcworkspace` |
| 3 | `xcodebuild build -workspace iOSDigitalWallet.xcworkspace -scheme iOSDigitalWallet -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' CODE_SIGNING_ALLOWED=NO` | exits 0; app shows the skeleton text |
| 4 | `git status` after `tuist generate` | `*.xcodeproj` / `*.xcworkspace` NOT listed (gitignored) — **negative guard** |
| 5 | `grep -n "tuist:packages:begin" Tuist/Package.swift` | marker present; region empty — brick anchor exists |
| 6 | Deployment target check: `grep -R "16.0" Tuist/ProjectDescriptionHelpers Project.swift` | iOS 16 set in exactly one helper, referenced by the app target |

## Definition of Done

- `tuist generate` + `xcodebuild build` green on a clean checkout via the pinned Tuist.
- `.xcodeproj`/`.xcworkspace` gitignored; `git status` clean after generate.
- Old `iOSDigitalWallet.xcodeproj/` + `iOSDigitalWallet/` folder removed.
- Marker regions present in `Tuist/Package.swift` and `Project.swift`.
- All 6 Verification Scenarios pass.

## Dependencies & Blockers

- Not blocked.
- Blocks [Task 2](task_2_ios_quality_tooling.md), [Task 3](task_3_ios_archtests_ci_docs.md), and all Phase 1 tasks (packages are wired via these manifests).

## References & Rollback

- Source Spec §4.1, §13, Changelog #2. Tuist docs: https://docs.tuist.dev
- Rollback: `git revert` the commit — restores the hand-managed `.xcodeproj`. No package code exists yet, so blast radius is the project shell only.
