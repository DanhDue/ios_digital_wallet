---
id: "task_15_ios_template_cleanup"
status: "backlog"
priority: "medium"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["template", "docs", "cleanup"]
order: "a15"
---

# Task 15: Genericize docs / agents / template cleanup

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Remove all references to "digital wallet" business domain from the template and genericize developer-facing documents + AI agent config. A developer cloning the template should see a neutral starting point, not a wallet app.

**Docs to update/genericize**:
- `docs/architecture/ARCHITECTURE.md` — already generic (written in Task 9), verify no wallet references remain.
- `README.md` (create if missing) — generic iOS super app template description: purpose, prerequisites (Xcode, Mason, SwiftLint, SwiftFormat), quick start (`clone → rename → mason make → build`).

**AI agent config to reset** (`.agents/`):
- `.agents/rules/CLAUDE.md` — already generic (behavioral rules, no wallet content). Keep as-is.
- Any other `.agents/` config files referencing wallet — genericize or remove.

**Project files to genericize**:
- `iOSDigitalWallet/Assets.xcassets/` — remove any digital-wallet-specific assets (wallet icons, card images). Keep only `AppIcon` placeholder and `AccentColor`.
- Remove any hardcoded API endpoints, secrets, or wallet-specific strings from `AppEnvironment.swift` (replace with `https://api.example.com`).

**Epic/task files to archive** (in `.devtool/`):
- These epic files stay — they are template documentation. No removal.

## Relevant Files & Context Pointers

- `README.md` — **NEW** or update existing
- `docs/architecture/ARCHITECTURE.md` — verify (written in Task 9)
- `iOSDigitalWallet/Assets.xcassets/` — audit and clean wallet-specific assets
- `Sources/Network/Sources/Network/Environment/AppEnvironment.swift` — replace wallet API URLs with placeholders
- `.agents/rules/CLAUDE.md` — verify (already generic)
- Reference: `flutter_super_app_template` §4.5 (docs/agent cleanup checklist — mirror)
- Reference: Android `task_15_rename_script_and_docs.md` in android_super_app_template

## Design Rationale

TDD adaptation: documentation + asset cleanup — no behavioral code. Verification is a text search for wallet-specific strings across the repo.

The `.devtool/epic/` and `.devtool/features/` directories stay in the template — they serve as architecture documentation and development workflow examples for teams adopting the template. New teams will see the ios_super_app_template epic as a completed reference for how to use the epic-designer skill on their own projects.

## TDD Checklist

TDD adapted — documentation/asset cleanup.

- [ ] **AUDIT**: `grep -r "digital.wallet\|DigitalWallet\|wallet\|wallet_api" --include="*.swift" --include="*.md" --include="*.yml" iOSDigitalWallet/ Sources/ docs/` → zero results (excluding epic/task docs which are intentionally about the template).
- [ ] **WRITE**: `README.md` — purpose, prerequisites, quick start, project structure overview.
- [ ] **CLEAN**: Remove wallet-specific assets from `Assets.xcassets/`.
- [ ] **REPLACE**: API base URL placeholders in `AppEnvironment.swift`.
- [ ] **VERIFY**: `xcodebuild build` still green after asset/string changes.

## Definition of Done

- Zero wallet-specific strings in `iOSDigitalWallet/` source + `Sources/` (grep clean).
- `README.md` written and describes the template clearly.
- `Assets.xcassets/` contains only generic `AppIcon` + `AccentColor`.
- `xcodebuild build` green.

## Dependencies & Blockers

- Blocked by [Task 12](task_12_ios_features_and_routing.md) (must know final structure before documenting it in README).
- Blocks [Task 16](task_16_ios_acceptance_test.md) (acceptance test validates the clean template).

## References & Rollback

- Source spec §8 (G8: template extraction), flutter_super_app_template §4.5.
- Rollback: `git revert`. Asset changes are the highest-risk (Xcode may regenerate catalog entries). Keep each cleanup as a separate commit for easier revert.
