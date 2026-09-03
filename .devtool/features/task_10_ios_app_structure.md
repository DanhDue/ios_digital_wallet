---
id: "task_10_ios_app_structure"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["architecture", "refactor", "structure"]
order: "a10"
---

# Task 10: Reorganize app target into App/ + Shell/ + Features/

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Reorganize `iOSDigitalWallet/` (the Xcode app target folder) from its current flat structure to the layered folder structure defined in the spec. This is a **pure structural move** — no new logic.

**Before** (current):
```
iOSDigitalWallet/
├── iOSDigitalWalletApp.swift
├── ContentView.swift (placeholder from Task 9)
└── Assets.xcassets/
```

**After** (target):
```
iOSDigitalWallet/
├── App/
│   └── iOSDigitalWalletApp.swift     ← moved
├── Shell/                              ← new folder (empty, filled in Task 11)
│   └── .gitkeep
├── Features/
│   ├── Settings/                       ← new folder (empty, filled in Task 12)
│   │   └── .gitkeep
│   └── Scanner/                        ← new folder (empty, filled in Task 12)
│       └── .gitkeep
└── Assets.xcassets/                    ← stays
```

**Xcode project impact**: Moving files in the filesystem does NOT automatically update Xcode's `.xcodeproj` file reference paths. Each moved file must be updated in Xcode (drag in Project Navigator or use `move` in project settings). This task requires manually updating `.pbxproj` path references.

Delete `ContentView.swift` — the placeholder from Task 9 is no longer needed; Shell (Task 11) will be the root view.

## Relevant Files & Context Pointers

- `iOSDigitalWallet/iOSDigitalWalletApp.swift` — move to `iOSDigitalWallet/App/`
- `iOSDigitalWallet/ContentView.swift` — delete
- `iOSDigitalWallet.xcodeproj/project.pbxproj` — path references update
- `iOSDigitalWallet/Shell/` — new folder group in Xcode
- `iOSDigitalWallet/Features/Settings/` — new folder group
- `iOSDigitalWallet/Features/Scanner/` — new folder group
- Reference: source spec §4.1 (target folder structure)

## Design Rationale

TDD adaptation: pure structural refactor — no behavior change. Verification is `xcodebuild build` succeeds after the move.

Doing this move as a **dedicated task** (not merged with Task 11) isolates the `.pbxproj` manipulation into a single, reviewable commit with a clear rollback. The blast radius of a corrupt `.pbxproj` is contained.

Xcode groups (not real filesystem folders by default) are set to "folder references" in this project — matching the filesystem structure and making it easier for command-line tools to reason about paths.

## TDD Checklist

TDD adapted — structural refactor, no new behavior.

- [ ] **MOVE**: In Xcode Project Navigator, move `iOSDigitalWalletApp.swift` into a new `App` group. Confirm `.xcodeproj` file reference path updates.
- [ ] **DELETE**: Remove `ContentView.swift` from Xcode project + filesystem.
- [ ] **CREATE**: Add `Shell/`, `Features/Settings/`, `Features/Scanner/` folder groups in Xcode with `.gitkeep` files.
- [ ] **BUILD**: `xcodebuild build -scheme iOSDigitalWallet` — must succeed with zero errors.
- [ ] **VERIFY**: `git status` shows only the structural moves + deletions — no logic changes.

## Definition of Done

- `iOSDigitalWallet/` folder structure matches spec §4.1.
- `xcodebuild build` green.
- `.pbxproj` references updated — no "missing file" warnings in Xcode.
- `ContentView.swift` deleted from both filesystem and project.

## Dependencies & Blockers

- Blocked by [Task 9](task_9_ios_rewire_arch_doc.md).
- Blocks [Task 11](task_11_ios_shell.md), [Task 12](task_12_ios_features_and_routing.md).

## References & Rollback

- Source spec §4.1 (folder structure).
- Rollback: `git revert` the commit. The `.pbxproj` is committed, so revert restores the original structure.
