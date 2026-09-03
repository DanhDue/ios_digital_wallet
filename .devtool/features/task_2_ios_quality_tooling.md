---
id: "task_2_ios_quality_tooling"
status: "todo"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: null
labels: ["tooling", "quality", "foundation"]
order: "a2"
---

# Task 2: SwiftLint + SwiftFormat quality tooling

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: B (tooling / config).** Verified by a Verification Scenarios table.

## Requirement Analysis

Establish the style gate for every Swift file in the template. SwiftLint here does **style + a thin layer safety net** — the heavy architectural enforcement is `ArchTests` (Task 3 / Task 9). Config lives in `quality/` at repo root so one `--config` path serves the app target and every SPM package.

- `quality/.swiftlint.yml`:
  - Standard opt-in rules; `line_length` warn 120 / error 160; `type_body_length`, `file_length` sane caps.
  - `custom_rules` (regex, defence-in-depth only — real check is ArchTests):
    - `no_ui_in_domain` — `included: ".*/Domain/.*\\.swift"`, `regex: "^\\s*import\\s+(UIKit|SwiftUI|Combine)\\b"`, severity `error`.
    - `no_public_in_data` — `included: ".*/Data/.*\\.swift"`, `regex: "^\\s*(public|open)\\s+(final\\s+)?(class|struct|enum|actor|protocol|func|var|let)"`, severity `error`.
- `quality/.swiftformat` — `--indent 4`, `--maxwidth 120`, `--importgrouping testable-bottom`, `--self remove`, `--trailingcommas always`.
- Wire into `Project.swift` (and `Module.swift` helper) a "SwiftLint" pre-build script phase: `if which swiftlint >/dev/null; then swiftlint lint --config "$SRCROOT/quality/.swiftlint.yml"; fi`.
- Add a `mise.toml` entry pinning `swiftlint` and `swiftformat` versions.

## Relevant Files & Context Pointers

- `quality/.swiftlint.yml`, `quality/.swiftformat` — **NEW**
- `Tuist/ProjectDescriptionHelpers/Module.swift` — add lint build-phase to the shared factory
- `Project.swift` — app target gets the lint phase via the helper
- `mise.toml` — pin swiftlint / swiftformat
- Source Spec §9.1; Android `buildSrc/src/main/kotlin/codeanalyzetools/` (parity reference)

## Design Rationale

Regex `custom_rules` are known-weak (the task files in v1 admitted this). v2 keeps only the two cheapest, highest-signal layer rules here so violations surface **inline in Xcode** during editing; correctness lives in `ArchTests` which reads the AST. `quality/` at root (not per-package) mirrors the Flutter template and avoids config duplication across 8 packages.

**Applicable skills:** none specific.

## Test Plan (Tier B — Verification Scenarios)

TDD adapted: config only.

| # | Scenario | Expected |
|---|---|---|
| 1 | `swiftlint lint --strict --config quality/.swiftlint.yml` on the skeleton | exits 0 (no violations) |
| 2 | `swiftformat --config quality/.swiftformat . --lint` | exits 0 |
| 3 | Add `import SwiftUI` to a temp file at `Packages/_probe/Domain/X.swift`, run SwiftLint | `no_ui_in_domain` flags it (exit 1) — **negative case**; delete probe |
| 4 | Add `public struct X {}` to `Packages/_probe/Data/X.swift`, run SwiftLint | `no_public_in_data` flags it; delete probe |
| 5 | Put `// public struct Fake {}` (comment) in a `Data/` file | rule does **not** fire — **false-positive guard** |
| 6 | `tuist generate && xcodebuild build ...` | lint build phase runs, build green on skeleton |

## Definition of Done

- `quality/.swiftlint.yml` + `quality/.swiftformat` exist; both tools pinned in `mise.toml`.
- `swiftlint --strict` and `swiftformat --lint` exit 0 on the skeleton.
- The 2 custom rules proven to fire on real violations and not on comments (Scenarios 3–5).
- Lint build phase active in the generated project.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_ios_tuist_bootstrap.md) (needs `Project.swift` / `Module.swift` helper).
- Blocks [Task 3](task_3_ios_archtests_ci_docs.md) (CI runs these) and all Phase 1 packages (must pass from day one).

## References & Rollback

- Source Spec §9.1. SwiftLint custom rules: https://realm.github.io/SwiftLint/custom-rules.html
- Rollback: delete `quality/` and remove the build phase from `Module.swift`. No other files change.
