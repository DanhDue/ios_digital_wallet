---
id: "task_12_rename_script_scheme"
status: "todo"
priority: "medium"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T03:42:16+07:00"
completedAt: null
labels: ["tooling", "scripts", "template"]
order: "a12"
---

# Task 12: rename_project.sh URL-Scheme Rewrite

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

`scripts/rename_project.sh` is the single entry point after cloning the template.
[Task 8](task_8_host_deeplink_wiring.md) introduces a URL scheme
(`iosdigitalwallet`) that the script does not currently rewrite: its existing
substitutions target `iOSDigitalWallet` (the app name, mixed case) and
`com.danhdue.iOSDigitalWallet` (the bundle id). A **lowercase** scheme matches
neither, so a renamed project would keep the template's scheme and two different
clones would fight over the same URL namespace on one device.

Add a third substitution:

- `OLD_SCHEME="iosdigitalwallet"` → `NEW_SCHEME` = `<NewAppName>` lowercased.
- Applied to `Tuist/ProjectDescriptionHelpers/Module.swift` (the single literal,
  per [Task 8](task_8_host_deeplink_wiring.md)) and to the docs that quote it
  (`README.md`, `docs/architecture/DEEPLINK.md`).
- Must preserve the script's existing guarantees: **clean-tree precondition**,
  **idempotency**, and `RENAME_SKIP_VERIFY=1` support.

Derivation rule: the app name is already validated as `^[A-Za-z][A-Za-z0-9]*$`,
so lowercasing it always yields a valid scheme (`^[a-z][a-z0-9]*$`). No extra
validation is required — state this in the script's comment header so the next
reader does not add a redundant check.

## Relevant Files & Context Pointers

- `scripts/rename_project.sh` — `OLD_BUNDLE` / `name_files` / `bundle_files` and the summary output
- `Tuist/ProjectDescriptionHelpers/Module.swift` — holds the `DEEPLINK_SCHEME` literal
- `App/Resources/Info.plist` — references `$(DEEPLINK_SCHEME)`, so it needs **no** rewrite
- `README.md` — quick-start and rename documentation
- `docs/architecture/DEEPLINK.md` — from [Task 14](task_14_deeplink_docs.md)

## Design Rationale

- **One literal, one substitution.** Because [Task 8](task_8_host_deeplink_wiring.md)
  puts the scheme in `Module.swift` and has `Info.plist` reference it through a
  build setting, the script rewrites exactly one source of truth. Had the scheme
  been hard-coded in the plist, the script would need to keep two places in sync.
- **Idempotency is the property most likely to break.** A second run must find no
  `iosdigitalwallet` occurrence and change nothing. The verification table pins
  this explicitly because it is the existing script's documented contract.
- **Docs are rewritten too.** A README that tells a renamed project to run
  `xcrun simctl openurl booted iosdigitalwallet://settings` is actively wrong.
- Applicable skill in `.agents/skills/`: **`verification-before-completion`** —
  Tier B evidence is executed commands and pasted output, never assertion.

## TDD Checklist

**TDD Adaptation:** this is a shell script performing textual substitution, with
no unit under test. Per the repo's Tier B standard the checklist is replaced by a
**Verification-Scenario table, executed and pasted**. The substitution is stated
rather than silently dropped.

| # | Scenario | Expected |
|---|---|---|
| 1 | `./scripts/rename_project.sh MyApp com.my.app` on a clean tree | `Module.swift` holds `myapp`; no `iosdigitalwallet` remains anywhere (`grep -ri` returns nothing outside `.git`) |
| 2 | Run the same command again | clean no-op; `git status` shows no modification |
| 3 | `tuist generate --no-open && xcodebuild build` after rename | builds; `Info.plist` resolves `$(DEEPLINK_SCHEME)` to `myapp` |
| 4 | `xcrun simctl openurl booted myapp://settings` on the renamed app | Settings tab opens |
| 5 | Run on a dirty tree | refuses with the existing clean-tree error |
| 6 | `./scripts/rename_project.sh 9bad com.my.app` | rejected by the existing name validation, before any file is touched |
| 7 | `RENAME_SKIP_VERIFY=1 ./scripts/rename_project.sh MyApp com.my.app` | performs substitutions, skips the build step |

- [ ] Execute every scenario on a throwaway clone and paste the real output.
- [ ] Confirm the script's printed summary now reports the scheme change
      alongside the name and bundle id.

## Definition of Done

- [ ] All seven verification scenarios executed with output pasted into the PR.
- [ ] `grep -ri iosdigitalwallet` over a renamed tree returns nothing outside
      `.git`.
- [ ] Idempotency preserved (scenario 2) — the script's headline guarantee.
- [ ] The script's comment header documents the scheme derivation rule and why no
      extra validation is needed.
- [ ] `shellcheck` clean if the repo runs it; otherwise `bash -n` passes.

## Dependencies & Blockers

- Blocked by [Task 8](task_8_host_deeplink_wiring.md) — the scheme literal must
  exist in `Module.swift` before the script can rewrite it.
- **Recommended**: run after [Task 14](task_14_deeplink_docs.md), which writes
  `DEEPLINK.md` — one of the files this script rewrites. Otherwise add the path
  defensively so the substitution does not fail on a missing file.

## References & Rollback

- Source Spec §4.10 (the URL scheme and keeping `rename_project.sh` honest).
- `README.md` — `scripts/rename_project.sh` documentation.
- **Rollback**: revert the script. A project renamed with the older script simply
  retains the template scheme — recoverable by editing one literal in
  `Module.swift` by hand.
