---
id: "task_12_rename_script_scheme"
status: "done"
priority: "medium"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-11T00:00:00+07:00"
completedAt: "2026-09-11T22:20:00+07:00"
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
- Must preserve the script's existing guarantees: **clean-tree precondition**,
  **idempotency**, and `RENAME_SKIP_VERIFY=1` support.

### Correction — the scheme is no longer confined to one file

This card was written before Tasks 9 and 14 existed, and its "one literal, one
substitution" premise is now **false**. The scheme token appears in eight places
across six files (case-sensitive `iosdigitalwallet`, outside the never-touch
zones):

| File | Hits | Reachable by an existing file list? |
|---|---|---|
| `Tuist/ProjectDescriptionHelpers/Module.swift` | 1 (the literal) | **NO** — `name_files` has `Tuist/Package.swift`, not this |
| `docs/architecture/DEEPLINK.md` | 5 | yes — `docs_md` |
| `App/UITests/DeepLinkOpenURLUITests.swift` | 2 | **NO** — lists cover `App/Sources` + `App/Tests` only |
| `App/Tests/AppTests/DeepLinkFlowTests.swift` | 1 | yes — `swift_tests` |
| `README.md` | 1 | yes — `root_md` |
| `App/Sources/Composition/AppComposition.swift` | 1 | **not the scheme** — see below |

Two of those directories are invisible to the script entirely.
`App/UITests/` was created by [Task 9](task_9_tier_c_acceptance_suite.md) after
this script was written, so **neither** the scheme **nor** the existing app-name
substitution reaches it. Today it happens to contain no `iOSDigitalWallet`
token, so there is no live bug — that is luck, not design. Add `App/UITests` to
the collected `swift_tests` so both substitutions cover it, and add
`Tuist/ProjectDescriptionHelpers/Module.swift` to the rewritten set.

### Correction — `com.iosdigitalwallet.session` is a trap, not a target

`App/Sources/Composition/AppComposition.swift:71` holds
`KeychainCacheStore(service: "com.iosdigitalwallet.session")`. It **contains**
the scheme token but **is not the scheme** — it is a Keychain service name, and
`OLD_BUNDLE` (`com.danhdue.iOSDigitalWallet`) does not match it either, so today
it tracks *neither* the bundle id *nor* the scheme.

Two consequences, both binding:

1. **A bare `s/iosdigitalwallet/…/g` would silently rewrite it** as collateral,
   changing a Keychain namespace as a side effect of a URL-scheme rename and
   misreporting it in the summary. This must not happen by accident.
2. It must still be renamed — for the card's own reason, applied to the other
   identity: a renamed clone that ships a Keychain service literally called
   `com.iosdigitalwallet.session` leaks the template's identity into every
   project, and two clones on one device share a Keychain service exactly as
   they would share a URL namespace.

So give it **its own explicit substitution**, `com.iosdigitalwallet.session`
→ `${NEW_BUNDLE}.session`, so it tracks the bundle id it is shaped like rather
than the scheme it merely resembles. Also rewrite the one doc that quotes it,
`docs/architecture/REFRESH_TOKEN.md:121` (already reachable via `docs_md`).

**Ordering is load-bearing.** Run the Keychain substitution *before* the bare
scheme substitution: once `com.iosdigitalwallet.session` has become
`com.acme.app.session`, the bare scheme replace has nothing left to catch
wrongly. This is the same most-specific-first discipline the script already
documents at step 5 ("bundle id FIRST, its string contains the name token as a
prefix") — follow that precedent rather than inventing regex anchoring, which
would be fragile against a future doc that writes the scheme without `://`.

Derivation rule: the app name is already validated as `^[A-Za-z][A-Za-z0-9]*$`,
so lowercasing it always yields a valid scheme (`^[a-z][a-z0-9]*$`). No extra
validation is required — state this in the script's comment header so the next
reader does not add a redundant check.

## Relevant Files & Context Pointers

- `scripts/rename_project.sh` — `OLD_BUNDLE` / `name_files` / `bundle_files` (:140-142), the substitution order (:149-159) and the summary output (:196-204)
- `Tuist/ProjectDescriptionHelpers/Module.swift:21` — holds the `deepLinkScheme` literal; **in no existing file list**
- `App/UITests/DeepLinkOpenURLUITests.swift:20,40` — **in no existing file list**; fold `App/UITests` into the collected `swift_tests`
- `App/Tests/AppTests/DeepLinkFlowTests.swift:16` — already reachable via `swift_tests`
- `App/Sources/Composition/AppComposition.swift:71` — the Keychain service; its own substitution, ordered first
- `docs/architecture/REFRESH_TOKEN.md:121` — quotes that Keychain service
- `App/Resources/Info.plist` — references `$(DEEPLINK_SCHEME)`, so it needs **no** rewrite
- `README.md:98` — quick-start smoke command
- `docs/architecture/DEEPLINK.md` — from [Task 14](task_14_deeplink_docs.md); 5 hits

## Design Rationale

- **One literal, many quotations.** [Task 8](task_8_host_deeplink_wiring.md)
  puts the scheme in `Module.swift` and has `Info.plist` reference it through a
  build setting, so there is exactly one *source of truth* to rewrite — but
  Tasks 9 and 14 added seven *quotations* of it in tests and docs, which go
  stale just as loudly. The single-source-of-truth design limits the blast
  radius in code; it does not limit it in prose. See the correction above.
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
| 4 | Scheme works end to end on the renamed app — drive it via `XCUIApplication.open(_:)` (run `DeepLinkOpenURLUITests` against the renamed clone), **not** `xcrun simctl openurl` | the deep link resolves and the target screen appears |
| 5 | Run on a dirty tree | refuses with the existing clean-tree error |
| 6 | `./scripts/rename_project.sh 9bad com.my.app` | rejected by the existing name validation, before any file is touched |
| 7 | `RENAME_SKIP_VERIFY=1 ./scripts/rename_project.sh MyApp com.my.app` | performs substitutions, skips the build step |

> **Scenario 4 was corrected.** As originally written it read
> `xcrun simctl openurl booted myapp://settings`.
> [Task 8](task_8_host_deeplink_wiring.md) and
> [Task 9](task_9_tier_c_acceptance_suite.md) established that on iOS 26 that
> command raises an "Open in '…'?" confirmation a bare shell cannot dismiss —
> which is precisely why `App/UITests/DeepLinkOpenURLUITests.swift` drives the
> OS through `XCUIApplication.open(_:)` instead. `README.md:98` still *shows*
> the `simctl` command, and that is correct: a human tapping **Open** in
> Simulator.app is the documented path, and the README already carries the
> confirmation-dialog note. Only the *scripted verification* had to change.
>
> Scenario 4 is the most expensive scenario here (full rename + generate +
> build + UI test on a throwaway clone). If it cannot be completed, say so
> plainly and report it unproven — do not substitute a weaker check and present
> it as scenario 4.

- [ ] Execute every scenario on a throwaway clone and paste the real output.
- [ ] Confirm the script's printed summary now reports the scheme change **and**
      the Keychain-service change alongside the name and bundle id — three
      identity lines, not one.

## Definition of Done

- [ ] All seven verification scenarios executed with output pasted into the PR.
- [ ] Over a renamed tree, **case-sensitive** `grep -rn iosdigitalwallet`
      returns nothing outside `.git` **and the never-touch zones**
      (`Packages/ bricks/ ArchTests/ scripts/ .devtool/`).

      > **This item was corrected.** It previously demanded that
      > `grep -ri iosdigitalwallet` return nothing at all, which no
      > implementation can satisfy: `-i` also matches `iOSDigitalWallet`, and
      > the script's own header, `OLD_SCHEME`/`OLD_BUNDLE` definitions, an
      > `ArchTests` comment and the whole of `.devtool/` legitimately keep both
      > tokens — the script documents `Packages/** bricks/** ArchTests/**
      > scripts/** .devtool/**` as a fixed vendor namespace it never touches.
      > A check that cannot pass gets waved through, which is worse than no
      > check.

- [ ] `com.iosdigitalwallet.session` is gone from `App/Sources/**` and
      `docs/**`, replaced by `${NEW_BUNDLE}.session` — and the scheme
      substitution is demonstrably *not* what removed it (show the Keychain
      substitution reported separately in the summary).
- [ ] Idempotency preserved (scenario 2) — the script's headline guarantee.
- [ ] The script's comment header documents the scheme derivation rule and why no
      extra validation is needed.
- [ ] `shellcheck` clean if the repo runs it; otherwise `bash -n` passes.

## Dependencies & Blockers

- Blocked by [Task 8](task_8_host_deeplink_wiring.md) — the scheme literal must
  exist in `Module.swift` before the script can rewrite it.
- **Resolved**: [Task 14](task_14_deeplink_docs.md) has landed and
  `docs/architecture/DEEPLINK.md` now exists, so the defensive-path caveat is
  moot. Note the file is reached through the `docs_md` glob rather than by name,
  and `replace_in` already skips absent files, so no path needs hardcoding.

## References & Rollback

- Verification record captured at implementation time: [task-12-rename-script-scheme.md](../epic/ios_deeplink_router/bdd/task-12-rename-script-scheme.md)
- Source Spec §4.10 (the URL scheme and keeping `rename_project.sh` honest).
- `README.md` — `scripts/rename_project.sh` documentation.
- **Rollback**: revert the script. A project renamed with the older script simply
  retains the template scheme — recoverable by editing one literal in
  `Module.swift` by hand.
