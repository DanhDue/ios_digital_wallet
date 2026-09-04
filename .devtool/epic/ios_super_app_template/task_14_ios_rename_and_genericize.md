---
id: "task_14_ios_rename_and_genericize"
status: "done"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: "2026-09-04T00:08:15Z"
labels: ["template", "tooling", "docs", "cleanup"]
order: "a14"
---

# Task 14: `rename_project.sh` + genericize docs / assets / README

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: B (script + cleanup).** Verification Scenarios table + a text-search audit.

## Requirement Analysis

**1. `scripts/rename_project.sh <NewAppName> <new.bundle.id>`** — the only entry point after clone. Because Tuist generates the project, this only rewrites manifests + moves the `App/` display identity; **no `.pbxproj` surgery**.

Steps:
1. Validate: `git status --porcelain` empty; two args; `NewAppName` is a valid Swift identifier; bundle id matches `^[a-z0-9.]+$`.
2. String-replace `iOSDigitalWallet` → `<NewAppName>` in `Project.swift`, `Workspace.swift`, `Tuist/Package.swift`, `App/Sources/**`, `App/Resources/Info.plist`, `*.md` (use `LC_ALL=C` + a portable in-place sed helper for macOS/Linux).
3. Replace `com.danhdue.iOSDigitalWallet` → `<new.bundle.id>` in `Project.swift`, `App/Resources/Info.plist`.
4. Rename the scheme / display name in `Project.swift`; `git mv App/Resources/Assets.xcassets` stays (no rename needed).
5. **Do NOT rename** infra/shell package names (`Core`, `Framework`, `Network`, `AppUIKit`, `Platform`, `Shell`) or `*Feature` package names — vendor namespace, fixed.
6. `tuist generate` then `xcodebuild build -scheme <NewAppName> -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' CODE_SIGNING_ALLOWED=NO`.
7. Print a summary of replacements + the verification result.

**2. Genericize** (remove "digital wallet" domain so a fresh clone is neutral):
- `grep -ri "wallet" --include=*.swift --include=*.md App/ Packages/ docs/` → 0 (excluding `.devtool/` epic docs, which stay as template documentation).
- `Packages/Network/Sources/Network/Environment/AppEnvironment.swift` — URLs already `https://api.example.com` (verify).
- `App/Resources/Assets.xcassets/` — only `AppIcon` placeholder + `AccentColor`.
- `README.md` — final structure section (8 packages + App + ArchTests), quick start (`clone → mise install → tuist generate → build`, then `mason make ios_mvi_feature`), the Testing tiers (§9A) summary.
- `AGENTS.md` / `PROJECT_RULES.md` — verify generic (no wallet references).

## Relevant Files & Context Pointers

- `scripts/rename_project.sh` — **NEW**
- `Project.swift`, `Workspace.swift`, `Tuist/Package.swift`, `App/Sources/**`, `App/Resources/Info.plist` — rename targets
- `README.md`, `AGENTS.md`, `PROJECT_RULES.md` — genericize / finalize
- `Packages/Network/Sources/Network/Environment/AppEnvironment.swift`, `App/Resources/Assets.xcassets/` — audit
- Source Spec §12 (rename script), §11 (root docs); Flutter `scripts/rename_project.sh` (macOS sed reference); Android `task_15` (parity)

## Design Rationale

Tuist collapses the rename to a manifest string-swap — the historically riskiest part (`.pbxproj`) is gone because it's generated and gitignored. Keeping infra/feature package names fixed matches the Flutter template's "vendor namespace" decision and keeps `mason` output stable across renamed projects.

**Applicable skills:** `elements-of-style` for README, if available.

## Test Plan (Tier B — Verification Scenarios)

Runs on a `git worktree` copy, reverted after.

| # | Scenario | Expected |
|---|---|---|
| 1 | `./scripts/rename_project.sh` (no args) | prints usage, exit 1 |
| 2 | dirty tree | exit 1 "uncommitted changes" |
| 3 | `./scripts/rename_project.sh 123Bad com.x.y` | rejects invalid identifier, exit 1 |
| 4 | `./scripts/rename_project.sh AcmeApp com.acme.app` on a clean worktree | exit 0; summary printed |
| 5 | after #4: `grep -r "iOSDigitalWallet" Project.swift Workspace.swift App/` | zero hits |
| 6 | after #4: `grep -n 'name: "Core"' Packages/Core/Package.swift` | still `Core` — infra namespace unchanged |
| 7 | after #4: `tuist generate && xcodebuild build -scheme AcmeApp ...` | exit 0 |
| 8 | re-run #4 on the already-renamed tree | clean no-op or clear "already renamed" message — idempotency guard |
| 9 | `grep -ri "wallet" --include=*.swift --include=*.md App/ Packages/ docs/` | zero hits (`.devtool/` excluded) |
| 10 | `Assets.xcassets` listing | only `AppIcon` + `AccentColor` |
| 11 | README quick-start followed literally on a fresh clone | app builds and runs |

## Definition of Done

- `scripts/rename_project.sh` executable; passes Scenarios 1–8.
- Zero "wallet" strings in `App/` + `Packages/` + `docs/` (Scenario 9); assets minimal; env URLs are placeholders.
- `README.md` accurate and followable; `AGENTS.md`/`PROJECT_RULES.md` generic.
- `xcodebuild build` green after rename.

## Dependencies & Blockers

- Blocked by [Task 12](task_12_ios_scanner_and_composition.md) (full structure must exist), [Task 13](task_13_ios_mason_bricks.md) (README documents the bricks).
- Blocks [Task 15](task_15_ios_acceptance_e2e.md).

## References & Rollback

- Source Spec §12, §11.
- Rollback: `git worktree remove` the test worktree; on `main`, `git revert` — each cleanup kept as its own commit for granular revert (assets are the highest-risk).
