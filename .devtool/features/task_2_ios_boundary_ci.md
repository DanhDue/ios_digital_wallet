---
id: "task_2_ios_boundary_ci"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["ci", "governance", "foundation"]
order: "a2"
---

# Task 2: Module boundary check script + GitHub Actions CI

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Two deliverables:

**1. `scripts/check_module_boundaries.sh`** — the iOS equivalent of Android's Konsist K1/K6 rule (no cross-Feature imports) + Flutter's `scripts/check_module_boundaries.sh`. Grep-based: scans `iOSDigitalWallet/Features/*/` for Swift files that import another Feature's types by class/struct name or namespace. Violations not listed in `scripts/module_boundary_whitelist.txt` exit with code 1.

Start with an empty whitelist (new project, no existing violations). Format: one `FeatureA→FeatureB` entry per line.

**2. `.github/workflows/ci.yml`** — GitHub Actions pipeline. Phase 0 scope: quality + boundary check + build. No signing, no Firebase secrets (mirrors Android Phase 0 rule: CI green without secrets first).

Jobs:
- `quality`: checkout → install SwiftLint + SwiftFormat (`brew install`) → SwiftLint check → SwiftFormat lint → boundary check script.
- `build-and-test`: depends on `quality` → resolve SPM packages → `xcodebuild test` with `CODE_SIGNING_ALLOWED=NO` → upload `.xcresult` artifact.

Trigger: `pull_request` + push to `develop`/`main`.

## Relevant Files & Context Pointers

- `scripts/check_module_boundaries.sh` — **NEW**
- `scripts/module_boundary_whitelist.txt` — **NEW** (empty for new project)
- `.github/workflows/ci.yml` — **NEW**
- `quality/.swiftlint.yml`, `quality/.swiftformat` — from [Task 1](task_1_ios_quality_tooling.md)
- Reference: `scripts/check_module_boundaries.sh` in Flutter template branch (`bloc_digital_wallet`) — adapt from that
- Reference: `.devtool/epic/android_super_app_template/` Tasks 2 & 3 (Konsist + GitHub Actions — analogues)

## Design Rationale

The boundary check is grep-based (not AST-based like Konsist) because there is no Konsist equivalent for Swift. This is a known weakness documented in the spec. The script checks for `import FeatureName` style imports — covers the most common violation pattern. SwiftLint's `no_public_in_data` and `no_ui_in_domain` rules from Task 1 handle the layer-level violations that Konsist K2/K3/K4 would catch in Android.

`CODE_SIGNING_ALLOWED=NO` avoids needing certificates in CI at Phase 0 — the key insight from the Android epic that kept Phase 0 CI green without secrets.

TDD adaptation: script + CI config, no runtime behavior. Verification is running the tools and asserting exit codes.

## TDD Checklist

TDD adapted — infrastructure/config task.

- [ ] **WRITE**: `scripts/check_module_boundaries.sh` with empty whitelist. Run it against current `iOSDigitalWallet/Features/` (empty) — exits 0.
- [ ] **VERIFY**: Manually create a test Swift file in `iOSDigitalWallet/Features/TestA/` that contains `import TestB` → run script → exits 1 with clear error message → delete test file.
- [ ] **WRITE**: `.github/workflows/ci.yml` with `quality` + `build-and-test` jobs. Validate YAML syntax (`yamllint` or GitHub Actions editor).
- [ ] **VERIFY**: Push to a branch, confirm GitHub Actions triggers and both jobs pass on Hello World app (no violations, build succeeds with `CODE_SIGNING_ALLOWED=NO`).
- [ ] **VERIFY**: CI `quality` job fails when a lint violation exists — introduce one, push, confirm red, revert.

## Definition of Done

- `scripts/check_module_boundaries.sh` exits 0 on current codebase; exits 1 on intentional cross-Feature import.
- `scripts/module_boundary_whitelist.txt` exists and is empty.
- `.github/workflows/ci.yml` triggers on PR and push; both jobs green on `main`.
- No signing secrets required.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_ios_quality_tooling.md) (needs `quality/` config files to exist).
- Blocks [Task 4](task_4_ios_core_package.md) (CI must be green before adding packages).

## References & Rollback

- Source spec §9.3 (GitHub Actions CI), §9.2 (boundary script).
- Rollback: delete `.github/workflows/ci.yml` and `scripts/`. No other files changed.
