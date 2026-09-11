# Verification Record — Task 12: rename_project.sh URL-Scheme Rewrite

Captured at implementation time (2026-09-11). A shell script performing
textual substitution has no unit under test, so the repo's TDD standard was
replaced by an executed Verification-Scenario table plus adversarial probes.
This record keeps the probes, because three of the four defects this task
shipped through were found by constructing an input nobody had asked for.
Task: [task_12_rename_script_scheme](../../../features/task_12_rename_script_scheme.md)

## The thing this task is actually about

The string `iosdigitalwallet` names **two different identities** in this repo:

- the **URL scheme**, declared once at `Tuist/ProjectDescriptionHelpers/Module.swift:21`
- a **Keychain service name**, `com.iosdigitalwallet.session`, at
  `App/Sources/Composition/AppComposition.swift:71` — which *contains* the
  scheme token but is bundle-id-shaped, and which matched neither `OLD_NAME`
  nor `OLD_BUNDLE`, so before this task it tracked nothing at all.

They must be rewritten to **different** values (`$NEW_SCHEME` vs
`${NEW_BUNDLE}.session`) and must never catch each other. The mechanism is
ordering: rewrite the more specific literal first, so the bare scheme replace
has nothing left to match wrongly.

## Verification scenarios (executed on throwaway clones)

| # | Scenario | Result |
|---|---|---|
| 1 | `rename_project.sh MyApp com.my.app` on a clean clone | rewrites name, bundle, scheme, Keychain service; exit 0 |
| 2 | Same command again | `nothing to do — project already renamed`, exit 0, empty `git status` |
| 3 | `tuist generate` + `xcodebuild build` after rename | builds; `Info.plist` resolves `$(DEEPLINK_SCHEME)` to `myapp` |
| 4 | Scheme end-to-end on the renamed app via `XCUIApplication.open(_:)` | `TEST SUCCEEDED`; xcresult records `Open com.my.app with URL myapp://scanner` |
| 5 | Dirty tree | refuses with the existing clean-tree error, exit 1 |
| 6 | `rename_project.sh 9bad com.my.app` | rejected by name validation before any file is touched, exit 1 |
| 7 | `RENAME_SKIP_VERIFY=1` | substitutes, skips the build |

**Scenario 4 was corrected before dispatch.** As originally written the card
said `xcrun simctl openurl booted myapp://settings`. Tasks 8 and 9 had already
established that on iOS 26 that command raises an "Open in '…'?" confirmation a
bare shell cannot dismiss — which is exactly why
`App/UITests/DeepLinkOpenURLUITests.swift` drives the OS through
`XCUIApplication.open(_:)`. `README.md`'s `simctl` command is **not** wrong and
was left alone: a human taps **Open**, and the README carries the dialog note.
Only the *scripted* verification had to change.

## Adversarial probes — what the scenario table did not catch

These are the record. Each one failed before the fix and passes after.

### P1 — Keychain literal in a file the guard did not cover

Plant `com.iosdigitalwallet.session` in `App/Tests/AppTests/`, in
`.github/workflows/ci.yml`, in `README.md`. Before the fix, `keychain_files`
was `$swift_sources $docs_md` while `scheme_files` was the whole of
`name_files` — so the bare scheme pass ran over files the Keychain pass never
saw.

```
before:  App/Tests/...  ->  com.myapp.session      (WRONG — mangled by the scheme pass)
         App/Sources/... ->  com.my.app.session     (correct)
after:   both            ->  com.my.app.session
```

Two different Keychain service names in one renamed project, with the bad
rewrites tallied and printed under the **"url scheme"** heading. Fixed by
`keychain_files="$scheme_files"`, with the invariant stated in the script:
**the Keychain substitution must run over at least every file the bare scheme
substitution runs over.**

### P2 — a new bundle id that contains the old scheme token

`rename_project.sh MyApp com.iosdigitalwallet.app`. Pass 1 wrote
`com.iosdigitalwallet.app.session`; the bare scheme pass then re-caught its own
predecessor's output and mangled it to `com.myapp.app.session` — while the
summary printed the value pass 1 *intended*. A summary that claims a value it
never wrote.

Fixed with a sentinel: `literal -> @@RENAME_KEYCHAIN_SERVICE@@` before the
scheme pass, `sentinel -> ${NEW_BUNDLE}.session` after it. Rejected two cheaper
options: validating the input away refuses a legal bundle id, and anchoring the
scheme regex is fragile against a doc that writes the scheme without `://`.

### P3 — abort inside the sentinel window (a regression the P2 fix introduced)

The sentinel created an intermediate state the script never had before: abort
between the two passes — `sed` failure, or realistically Ctrl-C — and
`@@RENAME_KEYCHAIN_SERVICE@@` is left in shipped Swift. It is a syntactically
valid string literal, so nothing at compile time flags it.

Fixed with a trap on EXIT/INT/TERM that names the placeholder and points at
`git checkout -- .` — a complete, safe undo precisely *because* the script
already refused to start on a dirty tree.

### P4 — signal latency (a regression the P3 fix introduced)

Bash does not act on a trapped signal while synchronously waiting on a
foreground child. A trap registered for the whole script therefore made it
ignore TERM/INT for the entire length of `tuist install` / `tuist generate` /
`xcodebuild build` — minutes in a real build, indefinitely if `xcodebuild`
hangs. Exit-status parity held perfectly, which is why every exit-status check
missed it: they measure *what* comes out, not *when*.

Fixed by scoping the trap's lifetime to the window it protects — registered
immediately before pass 1a, `trap - EXIT INT TERM` immediately after pass 1b.
That also removed the need for a `SENTINEL_ARMED` flag entirely.

```
kill-to-death during the verify step:   >12000 ms  ->  37 ms   (exit 143 both)
```

### P5 — the window is not too wide either

Make a file fail that is only *written* by a pass **after** the sentinel window
(`chmod 555 .github/workflows`, which `ci.yml` only matches during the project
name pass). The script fails there with a bare `sed: Permission denied` and
**no** trap banner — confirming that a failure outside the window gets none of
the mechanism, exactly as the header claims.

## Final substitution order

```
1a. com\.iosdigitalwallet\.session  ->  @@RENAME_KEYCHAIN_SERVICE@@   [trap installed]
2.  iosdigitalwallet                ->  $NEW_SCHEME
1b. @@RENAME_KEYCHAIN_SERVICE@@     ->  ${NEW_BUNDLE}.session         [trap removed]
3.  com\.danhdue\.iOSDigitalWallet  ->  $NEW_BUNDLE
4.  iOSDigitalWallet                ->  $NEW_NAME
```

Passes 3 and 4 are mixed-case and run under `LC_ALL=C`, so they cannot
interact with 1 or 2. All six pairings were checked.

## Residual, not proven

**SIGINT was never observed.** This sandbox cannot deliver `SIGINT` to a child
process — confirmed twice, independently, with a minimal control case that has
nothing to do with this script (a bare `trap ... INT` never fires here, while
the identical test with `TERM` works). SIGTERM is fully proven end to end, and
both signals share one handler parameterised only by signal name. That is
strong indirect evidence, but it is inference, not observation.

## Corrections made to the card before dispatch

1. Its premise — "one literal, one substitution" — was false as of Tasks 9 and
   14: eight occurrences across six files, two of them in directories
   (`Tuist/ProjectDescriptionHelpers/`, `App/UITests/`) that no file list in
   the script reached. The app-name substitution missed `App/UITests` too; it
   was only not a live bug because that directory happened to carry no
   `iOSDigitalWallet` token.
2. `com.iosdigitalwallet.session` identified as a trap, not a target.
3. Verification scenario 4 replaced (see above).
4. The DoD demanded `grep -ri iosdigitalwallet` return nothing outside `.git`,
   which nothing can satisfy: `-i` also matches `iOSDigitalWallet`, and the
   script's own header, an `ArchTests` comment and all of `.devtool/`
   legitimately keep both tokens. Scoped to case-sensitive, excluding the
   documented never-touch zones. An unsatisfiable check gets waved through,
   which is worse than no check.
