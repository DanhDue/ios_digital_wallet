---
id: "task_15_rename_script_and_docs"
status: "done"
priority: "medium"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:28.152Z"
completedAt: "2026-09-03T03:30:28.152Z"
labels: ["template", "tooling", "docs"]
order: "a1d"
---
# Task 15: `rename_project.sh` + docs/agent genericization

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

The single post-clone entrypoint (Goal G8).

**`scripts/rename_project.sh <app_name> <bundle_id> [<display_name>] [--force]`**:
- validate `app_name` (`^[a-z][a-z0-9_]*$`), `bundle_id` (reverse-DNS)
- clean-tree guard unless `--force`; ERR trap with a recovery hint
- rewrite:
  - Kotlin package `com.danhdue.androiddigitalwallet` → `<bundle_id>` (base) and every module namespace `com.danhdue.<module>` → `<bundle_id>.<module>` — `git mv` the source directory trees + rewrite `package`/`import` statements
  - `applicationId`, `namespace` in every `build.gradle.kts` (`app` + all modules)
  - `AppConfig.kt` (`namespace`, `applicationId`, app name), `AndroidManifest.xml` `android:label`, string `app_name`
  - `settings.gradle.kts` `rootProject.name`
  - `README.md` / doc titles
- **do not touch**: `google-services.json` / signing configs (the consumer supplies their own; none are committed here anyway)
- end with `./gradlew :konsist-test:test assembleDebug` (or at least `help`) to verify the rewrite compiles; non-zero exit aborts loud
- unlike the Flutter template there is **no fixed vendor namespace to preserve** (native has no equivalent of the two Flutter plugin packages) — the script rewrites everything under `com.danhdue.*`

**Docs / agent genericization**:
- `docs/` — keep `architecture/`, `MASON_GUIDE.md`; prune or genericize wallet-specific analyses (`MVI_ANALYSIS.md` keep, `resolved_issues_analysis.md` / `system-design/NETWORK_ARCHITECTURE_ANALYSIS.md` genericize or drop)
- `AGENTS.md`, `PROJECT_RULES.md`, `.agent/rules/CRITICAL_RULES.md`, root `ARCHITECTURE.md` — remove "digital wallet" naming, point at `docs/architecture/ARCHITECTURE.md`
- `.agent/skills/` — keep `quality_check`, `pr_review`, `moshi_dto_generator`, `api_integration` (all generic); scrub wallet examples in their bodies
- `.aiproject`, `.cursorrules`, `.editorconfig` — genericize / keep
- add `docs/getting-started/` template-usage guide (parallel to the Flutter `template-usage-guide`)

## Relevant Files & Context Pointers

- NEW: `scripts/rename_project.sh`
- `buildSrc/src/main/kotlin/AppConfig.kt`, `settings.gradle.kts`, every `*/build.gradle.kts`
- `app/src/main/AndroidManifest.xml`, `app/src/main/res/values/strings.xml`
- `AGENTS.md`, `PROJECT_RULES.md`, `ARCHITECTURE.md`, `README.md`, `.agent/**`, `.aiproject`, `.cursorrules`
- `docs/**`
- Reference: `bloc_digital_wallet/.worktrees/flutter_super_app_template/scripts/rename_project.sh` (structure, arg parsing, ERR trap, "never rewritten" section) + `docs/getting-started/template-usage-guide.*`

## Design Rationale

Mirrors the Flutter `rename_project.sh` contract (single entrypoint, clean-tree guard, self-verifying end step) minus the vendor-namespace carve-out. Genericizing docs now — after the structure is final — avoids re-doing it.

Applicable skill: `@quality_check` after; `elements-of-style` for the usage guide if available.

## TDD Checklist

**TDD Adaptation** — a shell script + doc edits. Verifiable steps:

- [ ] On a fresh worktree copy: `scripts/rename_project.sh acme_wallet com.acme.wallet "Acme Wallet"` → `git grep -n "com.danhdue" ` returns nothing in source; `git grep -ni "digital wallet"` returns nothing in docs.
- [ ] `./gradlew :konsist-test:test assembleDebug` green after rename.
- [ ] App launches with the new label / applicationId (`adb shell pm list packages | grep acme`).
- [ ] Re-run on a dirty tree without `--force` → aborts with the guard message.
- [ ] Broken run mid-way (simulate) → ERR trap prints the recovery hint.

## Definition of Done

- `scripts/rename_project.sh` renames package/appId/namespace/label/rootProject.name in one pass and self-verifies.
- No `com.danhdue` / "digital wallet" strings remain after a rename (except intentional history/docs).
- Docs + agent config are project-neutral; a `template-usage-guide` exists.

## Dependencies & Blockers

- Blocked by [Task 13](task_13_strip_domain_to_template.md).
- Blocks [Task 16](task_16_e2e_acceptance_validation.md).

## References & Rollback

- Source spec §8.
- Rollback: worktree-only — `git checkout` the pre-task commit.