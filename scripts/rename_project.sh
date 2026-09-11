#!/usr/bin/env bash
#
# rename_project.sh — the single entry point after cloning this template.
# ---------------------------------------------------------------------------
# Renames the shipped project identity `iOSDigitalWallet` /
# `com.danhdue.iOSDigitalWallet` to your own app name + bundle id.
#
# Usage:
#   ./scripts/rename_project.sh <NewAppName> <new.bundle.id>
#   ./scripts/rename_project.sh AcmeApp com.acme.app
#
#   <NewAppName>    a valid Swift identifier: ^[A-Za-z][A-Za-z0-9]*$
#                   (no spaces, no punctuation — it becomes the Tuist project
#                   name, the scheme name and the `@main` struct name)
#   <new.bundle.id> reverse-DNS bundle id: ^[a-z0-9]+(\.[a-z0-9]+)+$
#
# What it rewrites (Source Spec §12):
#   * Tuist manifests            — Project.swift, Workspace.swift,
#                                  Tuist/Package.swift
#   * App identity               — App/Sources/**, App/Tests/**, App/UITests/**,
#                                  App/Resources/Info.plist
#   * Docs / CI                  — *.md at repo root, docs/**/*.md,
#                                  .github/workflows/*.yml
#   * The bundle id              — Project.swift, App/Resources/Info.plist,
#                                  App/Sources/Composition/ConsoleLogger.swift,
#                                  App/Tests/**, App/UITests/**
#   * The URL scheme             — runs over the SAME file superset as the
#                                  project name below: Module.swift (the one
#                                  source-of-truth literal) plus everything
#                                  the three bullets above collect —
#                                  Project.swift, Workspace.swift,
#                                  Tuist/Package.swift, App/Sources/**,
#                                  App/Tests/**, App/UITests/**,
#                                  App/Resources/Info.plist, *.md at repo
#                                  root, docs/**/*.md, .github/workflows/*.yml
#                                  — plus quality/.swiftlint.yml and
#                                  quality/.swiftformat. (An earlier version
#                                  of this comment claimed a narrower set —
#                                  just the App/Tests, App/UITests, root *.md
#                                  and docs/**/*.md quotations — which
#                                  understated the reach and obscured exactly
#                                  where the Keychain trap below lives: fix
#                                  round 1.) App/Resources/Info.plist is
#                                  scanned but never actually matches — it
#                                  reads the scheme back via the
#                                  $(DEEPLINK_SCHEME) build setting, so it
#                                  needs no rewrite of its own. Derived as
#                                  <NewAppName> lowercased — the app name is
#                                  already validated as ^[A-Za-z][A-Za-z0-9]*$,
#                                  so the lowercased form is always a valid
#                                  scheme (^[a-z][a-z0-9]*$); no extra
#                                  validation is required.
#   * The Keychain service       — the literal "com.iosdigitalwallet.session"
#                                  (today found in
#                                  App/Sources/Composition/AppComposition.swift
#                                  and docs/architecture/REFRESH_TOKEN.md). It
#                                  contains the scheme token but is shaped
#                                  like (and rewritten to) a bundle id, not
#                                  the scheme. Scanned over the IDENTICAL file
#                                  superset as the URL scheme above
#                                  (keychain_files=$scheme_files) — it must
#                                  never be narrower than the scheme's reach,
#                                  or the bare scheme pass can mangle an
#                                  unprotected Keychain literal in a file the
#                                  scheme pass reaches but the Keychain pass
#                                  does not. (Fix round 1: a hand-picked
#                                  subset — App/Sources/** + docs/** only —
#                                  missed App/Tests/**, App/UITests/**,
#                                  Project.swift and more, and let exactly
#                                  that happen.) Rewritten in two passes that
#                                  bracket the bare scheme pass, via a
#                                  sentinel placeholder: literal -> sentinel,
#                                  THEN the scheme pass, THEN sentinel ->
#                                  <new.bundle.id>.session — so a
#                                  <new.bundle.id> that itself contains the
#                                  substring "iosdigitalwallet" is never
#                                  exposed to the scheme pass (see step 5).
#   * Renames App/Sources/iOSDigitalWalletApp.swift -> <NewAppName>App.swift
#     via `git mv` (history preserved).
#
# What it NEVER touches (fixed "vendor namespace"):
#   Packages/**  bricks/**  ArchTests/**  scripts/**  .devtool/**
#   — the infra / Shell / *Feature package names (Core, Framework, Network,
#     AppUIKit, Platform, Shell, SettingsFeature, ScannerFeature) stay put so
#     Mason brick output is stable across every renamed project.
#
# `.xcodeproj` / `.xcworkspace` are generated by Tuist and git-ignored — there
# is no `.pbxproj` surgery here.
#
# Known limitation: the idempotency guard (below) only checks for
# App/Sources/<OldName>App.swift and the old name token in Project.swift. A
# project already renamed by an OLDER copy of this script (name + bundle id
# only, predating the scheme/Keychain substitutions) looks "already renamed"
# and exits early WITHOUT picking up the scheme/Keychain rewrite. That is a
# known gap, not a bug to fix here — repair such a project by hand-editing the
# one literal in Tuist/ProjectDescriptionHelpers/Module.swift (see the task
# card's Rollback note).
#
# The sentinel window (fix round 2, scoped in fix round 3): between the
# Keychain-service literal being replaced with the placeholder
# @@RENAME_KEYCHAIN_SERVICE@@ and that placeholder being resolved to its
# real value (step 5's passes 1a/1b), an abort — Ctrl-C, a killed process, a
# mid-run `sed` failure (e.g. a read-only directory) — can leave the
# placeholder stranded in a shipped file. It is a syntactically valid string
# literal wherever it lands, so nothing at compile time flags it. A trap on
# EXIT/INT/TERM detects exactly this window and prints a loud recovery
# message pointing at `git checkout -- .`, which is always a complete, safe
# undo here BECAUSE step 3 already required a clean tree before the script
# started — there is nothing to lose.
#
# The trap is installed immediately before pass 1a and REMOVED (`trap -
# EXIT INT TERM`) immediately after pass 1b returns — it exists only for the
# duration of the window it protects, nowhere else. This is deliberate, not
# an oversight: bash defers acting on a caught signal until the current
# foreground child returns, so a trap left registered for the WHOLE script
# would silently disable prompt Ctrl-C / `kill` for as long as `tuist
# install` / `tuist generate` / `xcodebuild build` keeps running afterward —
# minutes in a real build. Outside this narrow window this script installs
# no trap at all and behaves exactly as if the sentinel mechanism did not
# exist. The trap never changes the script's own exit status on any path
# (including a caught signal, which still surfaces to the caller as a signal
# death); it only adds a warning when the sentinel window was left open.
#
# Environment:
#   RENAME_SKIP_VERIFY=1   skip the `tuist generate` + `xcodebuild build`
#                          verification step (useful for a dry run).
#
# Exit status: 0 on success (or when the project is already renamed), 1 on any
# validation failure, non-zero if the verification build fails.

set -eu

OLD_NAME="iOSDigitalWallet"
OLD_BUNDLE="com.danhdue.iOSDigitalWallet"
OLD_SCHEME="iosdigitalwallet"
APP_ENTRY="App/Sources/${OLD_NAME}App.swift"
# Placeholder used to shield the Keychain-service rewrite from the bare
# scheme substitution that runs in between its two passes (fix round 1 —
# see step 5). Contains no regex-special or sed-delimiter characters.
KEYCHAIN_SENTINEL="@@RENAME_KEYCHAIN_SERVICE@@"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

usage() {
  cat >&2 <<EOF
usage: ./scripts/rename_project.sh <NewAppName> <new.bundle.id>

  <NewAppName>     valid Swift identifier  ^[A-Za-z][A-Za-z0-9]*\$   e.g. AcmeApp
  <new.bundle.id>  reverse-DNS bundle id   ^[a-z0-9]+(\.[a-z0-9]+)+\$  e.g. com.acme.app

example:
  ./scripts/rename_project.sh AcmeApp com.acme.app
EOF
}

die() {
  echo "rename_project: $1" >&2
  exit 1
}

# --- portable in-place sed (BSD vs GNU), detected once --------------------
if sed --version >/dev/null 2>&1; then
  _sed_inplace() { LC_ALL=C sed -i -e "$1" "$2"; }   # GNU
else
  _sed_inplace() { LC_ALL=C sed -i '' -e "$1" "$2"; } # BSD / macOS
fi

# replace <pattern> <replacement> <file...> — skips files that do not exist,
# only rewrites files that actually contain the pattern.
replace_in() {
  pattern="$1"; replacement="$2"; shift 2
  for f in "$@"; do
    [ -f "$f" ] || continue
    if LC_ALL=C grep -q -e "$pattern" "$f"; then
      _sed_inplace "s/${pattern}/${replacement}/g" "$f"
      echo "  rewrote  $f"
      TOUCHED=$((TOUCHED + 1))
    fi
  done
}

# --- sentinel-window trap (fix round 2, scoped in fix round 3) ------------
# These three functions are only ever REGISTERED (via `trap`) for the
# duration of the sentinel window itself — installed immediately before pass
# 1a, removed immediately after pass 1b returns (see step 5). Firing at all
# already means "inside the window," so unlike fix round 2 there is no
# separate armed/disarmed flag to check here — defining the functions here,
# ahead of that window, costs nothing since a function definition alone does
# not activate anything; only the `trap` calls in step 5 do.

# Prints the loud recovery message. Never touches $?; callers are
# responsible for preserving it across this call.
# shellcheck disable=SC2329  # invoked indirectly, via the traps armed in step 5
_sentinel_warn() {
  cat >&2 <<EOF

################################################################################
rename_project: ABORTED while a placeholder was written to disk.

One or more files may currently contain the literal string

    $KEYCHAIN_SENTINEL

in place of the app's Keychain service identifier. This is NOT a real value
— it is a temporary placeholder this script uses while rewriting the
Keychain service name (see "The sentinel window" near the top of this
script). It is syntactically valid wherever it landed (for example, inside a
Swift string literal), so nothing at compile time will flag it — do not ship
it.

RECOVERY: run
    git checkout -- .
This is a complete, safe undo: the script refused to start unless your
working tree was already clean, so that command returns you exactly to that
clean starting point — nothing you had before running this script is lost.
################################################################################

EOF
}

# EXIT fires for every termination this script causes itself while this
# trap is REGISTERED (see step 5 — only during the sentinel window): falling
# off the end, an explicit `exit N`, or `set -e` reacting to a failing
# command (e.g. `sed` failing on a read-only directory mid-substitution). $?
# is captured as the FIRST statement, before running anything else that
# could overwrite it (a bare `cat`/`[` would otherwise leave $? as ITS OWN
# status, silently turning a failure into a reported success) — and is the
# exact value re-raised via `exit` at the end, so this trap changes nothing
# about the script's own exit status on any path.
# shellcheck disable=SC2329  # invoked indirectly, via `trap ... EXIT` in step 5
_sentinel_trap_exit() {
  ec=$?
  _sentinel_warn
  exit "$ec"
}

# INT/TERM are asynchronous signals, not exit paths — bash runs this instead
# of the default "terminate" action, so without re-raising, the script would
# simply keep running from wherever it was interrupted. Disarm every trap
# first, THEN re-send the same signal to this process: with no trap left to
# catch it, the kernel's default disposition (terminate) applies, and the
# caller observes a genuine signal death (conventionally exit status
# 128+signal) exactly as it would have without this trap installed at all —
# not whatever this handler's own last command happened to return.
# shellcheck disable=SC2329  # invoked indirectly, via `trap ... INT TERM` in step 5
_sentinel_trap_signal() {
  local sig="$1"
  _sentinel_warn
  trap - EXIT INT TERM
  kill "-$sig" "$$"
}

# ------------------------------------------------------------------------
# 1. Validate arguments (independent of tree state)
# ------------------------------------------------------------------------
if [ "$#" -ne 2 ]; then
  usage
  exit 1
fi

NEW_NAME="$1"
NEW_BUNDLE="$2"

printf '%s' "$NEW_NAME" | LC_ALL=C grep -Eq '^[A-Za-z][A-Za-z0-9]*$' \
  || die "invalid app name '$NEW_NAME' — must match ^[A-Za-z][A-Za-z0-9]*\$ (a valid Swift identifier, no spaces)"

printf '%s' "$NEW_BUNDLE" | LC_ALL=C grep -Eq '^[a-z0-9]+(\.[a-z0-9]+)+$' \
  || die "invalid bundle id '$NEW_BUNDLE' — must match ^[a-z0-9]+(\.[a-z0-9]+)+\$ (reverse-DNS, lowercase)"

# The app name is already validated above as ^[A-Za-z][A-Za-z0-9]*$, so its
# lowercased form always satisfies ^[a-z][a-z0-9]*$ — a valid URL scheme.
# No separate scheme validation is required.
NEW_SCHEME="$(printf '%s' "$NEW_NAME" | LC_ALL=C tr '[:upper:]' '[:lower:]')"

# ------------------------------------------------------------------------
# 2. Idempotency guard — bail cleanly if already renamed
# ------------------------------------------------------------------------
if [ ! -f "$APP_ENTRY" ] && ! LC_ALL=C grep -q "$OLD_NAME" Project.swift 2>/dev/null; then
  echo "rename_project: nothing to do — project already renamed"
  echo "  ('$OLD_NAME' token absent from Project.swift and $APP_ENTRY already moved)."
  exit 0
fi

# ------------------------------------------------------------------------
# 3. Require a clean git tree
# ------------------------------------------------------------------------
if [ -n "$(git status --porcelain)" ]; then
  die "working tree is dirty — commit or stash your changes first"
fi

# ------------------------------------------------------------------------
# 4. Collect the file lists
# ------------------------------------------------------------------------
swift_sources=""
[ -d App/Sources ] && swift_sources="$(find App/Sources -type f -name '*.swift')"
# App/Tests/** and App/UITests/** are both test targets that quote the app
# name / bundle id / scheme; fold both into one collected list so every
# substitution that uses $swift_tests reaches App/UITests too.
test_dirs=""
[ -d App/Tests ] && test_dirs="$test_dirs App/Tests"
[ -d App/UITests ] && test_dirs="$test_dirs App/UITests"
swift_tests=""
# shellcheck disable=SC2086
[ -n "$test_dirs" ] && swift_tests="$(find $test_dirs -type f -name '*.swift')"
root_md="$(find . -maxdepth 1 -type f -name '*.md')"
docs_md=""
[ -d docs ] && docs_md="$(find docs -type f -name '*.md')"
ci_yml=""
[ -d .github/workflows ] && ci_yml="$(find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \))"

# shellcheck disable=SC2086
name_files="Project.swift Workspace.swift Tuist/Package.swift App/Resources/Info.plist quality/.swiftlint.yml quality/.swiftformat $swift_sources $swift_tests $root_md $docs_md $ci_yml"
# shellcheck disable=SC2086
bundle_files="Project.swift App/Resources/Info.plist App/Sources/Composition/ConsoleLogger.swift $swift_tests"
# The scheme lives in one source-of-truth literal (Module.swift) plus every
# quotation reached by $name_files (tests, docs, README) — reuse that list
# rather than inventing a parallel one.
# shellcheck disable=SC2086
scheme_files="Tuist/ProjectDescriptionHelpers/Module.swift $name_files"
# INVARIANT (fix round 1): the Keychain substitution must run over AT LEAST
# every file the bare scheme substitution runs over. The Keychain literal
# contains the scheme token as a substring, so any file the scheme pass can
# reach but the Keychain pass cannot is a file where an unprotected Keychain
# literal would be silently mangled as collateral by the scheme pass — which
# is the one thing the most-specific-first ordering exists to prevent (see
# step 5). A hand-picked subset (previously "$swift_sources $docs_md",
# matching only the Definition of Done's two known locations) is exactly
# what failed: it missed App/Tests/**, App/UITests/**, Project.swift,
# Workspace.swift, Tuist/Package.swift, quality/* and .github/workflows/*,
# all of which the scheme pass does reach. Reuse $scheme_files wholesale
# instead of re-deriving or narrowing it.
keychain_files="$scheme_files"

TOUCHED=0

echo "rename_project: $OLD_NAME -> $NEW_NAME   |   $OLD_BUNDLE -> $NEW_BUNDLE   |   $OLD_SCHEME -> $NEW_SCHEME"
echo

# ------------------------------------------------------------------------
# 5. Most-specific-first, extended for the scheme and its Keychain lookalike.
#    The Keychain substitution is a single LOGICAL rewrite (real literal ->
#    ${NEW_BUNDLE}.session) split into two PHYSICAL passes that bracket the
#    bare scheme pass, via a sentinel placeholder:
#      1a. Keychain literal -> $KEYCHAIN_SENTINEL, over $keychain_files
#          (== $scheme_files — see the invariant comment above step 4's
#          keychain_files assignment). Must run first: it is what makes
#          step 2 safe to run unguarded over the same files.
#      2.  the bare scheme, over $scheme_files (safe now — nothing spelling
#          "iosdigitalwallet" survives outside the sentinel, which does not
#          contain that substring).
#      1b. $KEYCHAIN_SENTINEL -> the real ${NEW_BUNDLE}.session, over the
#          SAME $keychain_files. Must run AFTER step 2, not before: if
#          NEW_BUNDLE itself contains the substring "iosdigitalwallet" (e.g.
#          `com.iosdigitalwallet.app`), writing the final value before step 2
#          would hand step 2 a fresh, unprotected match to re-mangle (fix
#          round 1 — see the regression probe in the task report).
#      3.  the bundle id (its string contains the name token as a prefix)
#      4.  the project name
#    Passes 1a and 1b together count as ONE substitution for the summary's
#    KEYCHAIN_TOUCHED tally (see below) — 1b is bookkeeping to finish what 1a
#    started, not a second independent rewrite.
# ------------------------------------------------------------------------
echo "keychain service (bundle-shaped, NOT the scheme) — pass 1/2 (protect):"
_before=$TOUCHED
# Register the sentinel-window trap BEFORE the call, not after it returns:
# if _sed_inplace fails partway through this file list (replace_in's loop,
# under set -e), the script exits mid-loop and a registration on the far
# side would never run — leaving the files already-rewritten-to-sentinel
# unguarded. Registering first covers that case, not just the (narrower) gap
# between a fully-completed pass 1a and pass 1b. This trap is intentionally
# scoped to exist ONLY through pass 1b below (fix round 3) — see "The
# sentinel window" in the header for why it must not stay registered for the
# rest of the script.
trap _sentinel_trap_exit EXIT
trap '_sentinel_trap_signal INT' INT
trap '_sentinel_trap_signal TERM' TERM
# shellcheck disable=SC2086
replace_in 'com\.iosdigitalwallet\.session' "$KEYCHAIN_SENTINEL" $keychain_files
KEYCHAIN_TOUCHED=$((TOUCHED - _before))

echo "url scheme:"
_before=$TOUCHED
# shellcheck disable=SC2086
replace_in 'iosdigitalwallet' "$NEW_SCHEME" $scheme_files
SCHEME_TOUCHED=$((TOUCHED - _before))

echo "keychain service — pass 2/2 (resolve sentinel to final value):"
_before=$TOUCHED
# shellcheck disable=SC2086
replace_in "$KEYCHAIN_SENTINEL" "${NEW_BUNDLE}.session" $keychain_files
# Only remove the trap once pass 1b has FULLY returned — same reasoning as
# registering it early: a partial failure here still leaves some files
# sentineled, and the trap must still be there to catch that. From here on
# this script has no trap at all, same as before this mechanism existed.
trap - EXIT INT TERM
# Passes 1a/1b are one logical substitution (see the block comment above):
# discard pass 1b's delta so it does not double-count against either
# KEYCHAIN_TOUCHED or the overall rewrite tally.
TOUCHED=$_before

echo "bundle id:"
# shellcheck disable=SC2086
replace_in 'com\.danhdue\.iOSDigitalWallet' "$NEW_BUNDLE" $bundle_files

echo "project name:"
# shellcheck disable=SC2086
replace_in 'iOSDigitalWallet' "$NEW_NAME" $name_files

# ------------------------------------------------------------------------
# 6. Move the @main entry-point file (struct body already rewritten above)
# ------------------------------------------------------------------------
MOVED="(none — $APP_ENTRY not found)"
if [ -f "$APP_ENTRY" ]; then
  git mv "$APP_ENTRY" "App/Sources/${NEW_NAME}App.swift"
  MOVED="git mv $APP_ENTRY -> App/Sources/${NEW_NAME}App.swift"
  echo "  $MOVED"
fi

# ------------------------------------------------------------------------
# 7. Verify: regenerate the project and build the renamed scheme
# ------------------------------------------------------------------------
VERIFY="SKIPPED (RENAME_SKIP_VERIFY=1)"
if [ "${RENAME_SKIP_VERIFY:-0}" != "1" ]; then
  echo
  echo "verify: tuist install"
  tuist install
  echo "verify: tuist generate --no-open"
  tuist generate --no-open
  echo "verify: xcodebuild build -scheme $NEW_NAME"
  if xcodebuild build \
      -workspace "${NEW_NAME}.xcworkspace" \
      -scheme "$NEW_NAME" \
      -destination 'generic/platform=iOS Simulator' \
      CODE_SIGNING_ALLOWED=NO; then
    VERIFY="PASS"
  else
    VERIFY="FAIL"
  fi
fi

# ------------------------------------------------------------------------
# 8. Summary
# ------------------------------------------------------------------------
echo
echo "=================== rename_project summary ==================="
echo "  app name     : $OLD_NAME  ->  $NEW_NAME"
echo "  bundle id    : $OLD_BUNDLE  ->  $NEW_BUNDLE"
echo "  url scheme   : $OLD_SCHEME  ->  $NEW_SCHEME   ($SCHEME_TOUCHED files)"
echo "  keychain svc : com.$OLD_SCHEME.session  ->  ${NEW_BUNDLE}.session   ($KEYCHAIN_TOUCHED files)"
echo "  rewrite passes : $TOUCHED   (one per substitution-x-file match; a file hit by more than one substitution is counted once per substitution, not once per file)"
echo "  entry point : $MOVED"
echo "  verify      : $VERIFY"
echo "  next        : review 'git diff', then commit; run 'mason get' for the bricks."
echo "============================================================="

[ "$VERIFY" = "FAIL" ] && exit 1
exit 0
