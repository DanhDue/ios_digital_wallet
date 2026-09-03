---
id: "task_3_ios_archtests_ci_docs"
status: "done"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: "2026-09-03T10:34:26Z"
labels: ["governance", "ci", "swift-syntax", "foundation"]
order: "a3"
---

# Task 3: ArchTests skeleton + boundary script + GitHub Actions CI + root docs

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: B (tooling / config).** The `ArchTests` package itself contains tests, but this task only stands up its **skeleton + one trivial rule**; the real rules land in Task 9 / Task 12.

## Requirement Analysis

Three deliverables that together make CI green and give governance a home.

**1. `ArchTests` SPM package** (`ArchTests/Package.swift`) — never linked into the app:
- `dependencies: [.package(url: "https://github.com/swiftlang/swift-syntax", exact: "<version matching Xcode's Swift>")]`. Pin the exact version; note it in `README`.
- `Sources/ArchTestSupport/`:
  - `RepoRoot.swift` — walks up from `#filePath` to the repo root (finds `Workspace.swift`).
  - `SyntaxScanner.swift` — given a directory glob, parses each `.swift` with `SwiftParser` and exposes `importDecls`, `topLevelDecls` (with modifiers), `inheritanceClauses`.
  - `Baseline.swift` — reads `ArchTests/baseline.txt` (known accepted violations, one `rule:path` per line); a rule passes if every finding is in the baseline.
  - `BoundaryWhitelist.swift` — reads `scripts/module_boundary_whitelist.txt` (`FeatureA->FeatureB` per line).
- `Tests/ArchTests/ScopeSanityTest.swift` — the one trivial rule now: asserts `RepoRoot` resolves and `SyntaxScanner` can parse at least one file under `App/Sources/`. (Green on the skeleton.)
- `baseline.txt` — empty. `scripts/module_boundary_whitelist.txt` — empty.

**2. `scripts/check_module_boundaries.sh`** — defensive grep: scans `Packages/Features/*/Sources/` for `import <OtherFeatureModule>`; any hit not in the whitelist → exit 1. Empty `Packages/Features/` ⇒ exit 0.

**3. `.github/workflows/ci.yml`** — 3 jobs on `pull_request` + push to `develop`/`main`:
- `quality`: checkout → `mise install` → `swiftlint --strict` → `swiftformat --lint` → `bash scripts/check_module_boundaries.sh` → `swift test --package-path ArchTests`.
- `packages`: loop `swift test --package-path` over every `Packages/*` and `Packages/Features/*` that exists (skeleton: none yet — loop is a no-op guarded by a glob check).
- `app`: needs `[quality, packages]` → `mise install` → `tuist generate --no-open` → `xcodebuild test -workspace ... -scheme iOSDigitalWallet -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' CODE_SIGNING_ALLOWED=NO`.

**4. Root docs** (parity with Android template payload): `README.md` (purpose, prerequisites = Xcode 16, mise, Tuist, SwiftLint, SwiftFormat, Mason; quick start clone → `mise install` → `tuist generate` → build; project layout overview), `AGENTS.md` + `PROJECT_RULES.md` (generic architecture rules, no wallet domain), `.editorconfig`, `ARCHITECTURE.md` (thin pointer stub → `docs/architecture/ARCHITECTURE.md`, filled in Task 9).

## Relevant Files & Context Pointers

- `ArchTests/Package.swift`, `ArchTests/Sources/ArchTestSupport/*.swift`, `ArchTests/Tests/ArchTests/ScopeSanityTest.swift`, `ArchTests/baseline.txt` — **NEW**
- `scripts/check_module_boundaries.sh`, `scripts/module_boundary_whitelist.txt` — **NEW**
- `.github/workflows/ci.yml` — **NEW**
- `README.md`, `AGENTS.md`, `PROJECT_RULES.md`, `.editorconfig`, `ARCHITECTURE.md` — **NEW**
- `Workspace.swift` — add the `ArchTests` package so `tuist edit` sees it (optional; `swift test --package-path` works standalone)
- Source Spec §9.2, §9.3, §9.4, §11 (root docs); Android `konsist-test/src/test/kotlin/com/danhdue/konsist/support/` (parity reference for support classes)

## Design Rationale

`ArchTests` is the `:konsist-test` analogue: a standalone SPM package with swift-syntax, run via `swift test`, invisible to the app build. Standing up the **support layer + one green rule** now (rather than all rules) keeps Phase 0 low-risk and lets CI go green immediately; real rules attach in Phase 1/2 when there's structure to check.

`swift-syntax` is version-locked to the compiler — pinning `exact:` and documenting it in README prevents "works on my Xcode" drift.

**Applicable skills:** none specific.

## Test Plan (Tier B — Verification Scenarios)

TDD adapted: skeleton + config. The one real test (`ScopeSanityTest`) follows normal RED→GREEN.

| # | Scenario | Expected |
|---|---|---|
| 1 | `swift test --package-path ArchTests` | resolves swift-syntax (pinned), `ScopeSanityTest` green |
| 2 | `bash scripts/check_module_boundaries.sh` on skeleton (no `Packages/Features/`) | exits 0 with "no features yet" |
| 3 | `mkdir -p Packages/Features/A/Sources/A Packages/Features/B/Sources/B; echo 'import B' > Packages/Features/A/Sources/A/x.swift; bash scripts/check_module_boundaries.sh` | exits 1, names `A->B` — **negative case**; clean up |
| 4 | add `A->B` to `scripts/module_boundary_whitelist.txt`, rerun Scenario 3 | exits 0 — whitelist honoured; clean up |
| 5 | comment `// import B` in `A` instead | script does **not** flag — **false-positive guard** |
| 6 | push a branch | all 3 CI jobs (`quality`, `packages`, `app`) green; no signing secrets used |
| 7 | introduce a SwiftFormat violation, push | `quality` job red; revert |
| 8 | `README.md` prerequisites list | includes Xcode 16, mise, Tuist (pinned version), SwiftLint, SwiftFormat, Mason |

## Definition of Done

- `swift test --package-path ArchTests` green; support classes (`RepoRoot`, `SyntaxScanner`, `Baseline`, `BoundaryWhitelist`) implemented and unit-covered.
- `check_module_boundaries.sh` + empty whitelist behave per Scenarios 2–5.
- CI: 3 jobs green on `main` with no secrets.
- Root docs present; `ARCHITECTURE.md` is a pointer stub; `README` quick-start is accurate for the skeleton.
- All Verification Scenarios pass.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_ios_tuist_bootstrap.md), [Task 2](task_2_ios_quality_tooling.md).
- Blocks [Task 4](task_4_ios_core_package.md) (packages must land on green CI) and [Task 9](task_9_ios_rewire_arch_doc.md) (fills in the real ArchTests rules + `docs/architecture/ARCHITECTURE.md`).

## References & Rollback

- Source Spec §9.2–§9.4, §11. swift-syntax: https://github.com/swiftlang/swift-syntax
- Rollback: delete `ArchTests/`, `scripts/`, `.github/workflows/ci.yml`, and the new root docs. Skeleton app still builds.
