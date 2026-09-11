# Verification Record — Task 14: Deep Link Documentation

Captured at implementation time (2026-09-11). Documentation has no runtime
behaviour to drive RED-first, so the repo's standard was replaced by a harder
one: every code sample had to compile and every command had to be executed.
This record is what was actually compiled and run, plus the stale claims the
pass uncovered in documents it did not set out to change.
Task: [task_14_deeplink_docs](../../../features/task_14_deeplink_docs.md)

## Verification: samples compiled, commands executed

**Compiled/run, not just eyeballed:**

- `xcodebuild build -workspace iOSDigitalWallet.xcworkspace -scheme
  iOSDigitalWallet -destination 'platform=iOS Simulator,name=iPhone 17'
  CODE_SIGNING_ALLOWED=NO` → `** BUILD SUCCEEDED **`. This proves the
  `ScannerRouteProvider.deepLinks`, `SessionDeepLinkGuard`, and
  `ShellTabResolver` samples in the doc (quoted verbatim from shipped
  source) compile, since they're part of this build.
- A scratch SwiftPM executable (`GrammarCheck`, built in the scratchpad
  dir, local `path:` dependency on the real `Packages/Platform` — no repo
  file touched) **ran** and asserted, all `PASS`:
  - custom-scheme host-prepending (`iosdigitalwallet://settings/language`
    → `["settings","language"]`)
  - https host-discarding (`https://example.com/settings/language` → same)
  - duplicate query key last-wins (`?tab=a&tab=b` → `"b"`)
  - path-beats-query precedence (`/tx/:id` vs `iosdigitalwallet://tx/123?id=999`
    → `"123"`)
  - parent-chain stack count (`/scanner/result/:code` → 2-element stack)
  - captured parameter propagation into the child route
- The `UserLoggedIn`-ordering sample (§4) and the `onContinueUserActivity`
  Universal Links sample (§6) were typechecked with
  `swiftc -typecheck -sdk <iphonesimulator SDK> -target
  arm64-apple-ios16.0-simulator -F <built-frameworks-dir>` against the
  `Platform.framework` / `Core.framework` produced by the `xcodebuild`
  build above — both typecheck cleanly, no diagnostics.
- `swift build --package-path Packages/Platform` and
  `swift test --package-path Packages/Platform` (177/177) after the
  `DeepLinkPattern.swift` doc-comment edit.
- `swift test --package-path ArchTests` (37/37) after the same edit.
- `swiftlint lint --config quality/.swiftlint.yml --quiet
  Packages/.../DeepLinkPattern.swift` and `swiftformat ... --lint` — both
  clean.
- `xcodebuild test ... -only-testing:iOSDigitalWalletTests` (47/47) and
  `-only-testing:iOSDigitalWalletUITests/DeepLinkOpenURLUITests` (2/2) —
  confirms the full baseline (App unit + UI) is unaffected.

**Every command shown was executed, with real output:**

- `xcrun simctl openurl booted "iosdigitalwallet://scanner/result/DEMO123"`
  — run against a freshly built, freshly installed app on a booted iPhone 17
  (iOS 26.2) simulator. Screenshot confirms the app actually navigated to
  the Scanner tab's Result screen showing "Mã đã quét: DEMO123" — a real
  deep-link round trip, not a coincidence of the cold-start tab.
- The iOS 26 "Open in '…'?" confirmation dialog was independently
  reproduced on an iPhone 17 simulator running **iOS 26.5** (screenshot
  captured) — it did **not** appear on the iOS 26.2 device. This is a
  genuine iOS-point-release difference I discovered by testing both, not
  something I could have gotten right by trusting the brief's fact alone;
  the README's wording ("iOS 26 **can** raise...") is phrased to be
  accurate across both observed behaviors rather than overclaiming.
- Ran `App/UITests/DeepLinkOpenURLUITests` for real on the iOS 26.5
  simulator: both tests passed, and the trace log shows XCUITest waiting on
  and tapping the "Open" button via its SpringBoard automation session —
  confirming `XCUIApplication.open(_:)` *also* raises the same OS dialog,
  and that only XCUITest (not a bare shell command) can get past it. I
  documented this precisely in `DEEPLINK.md` §3's testing note and in
  README's smoke-command caveat, rather than repeating the brief's shorthand
  ("`XCUIApplication.open(_:)` does not [raise the gate]") verbatim, since my
  own test showed both raise it — they differ in who can dismiss it.

## Other stale/discrepant claims found (beyond the four carried notes)

- None found in `ARCHITECTURE.md` §VII's other three rows (DFM, App
  Extensions, `epic-implementation` skill, `@Observable`) — re-read per the
  checklist; all still accurate.
- No other doc-comment inaccuracies found in the deep-link source files
  read (`DeepLink.swift`, `DeepLinkRoute.swift`, `DeepLinkGuard.swift`,
  `DeepLinkRouter.swift`, `TabResolver.swift`, `AnyAppRoute.swift`,
  `AppEvent.swift`) — all cross-checked against source and/or execution.

## Concerns

- The brief's "Facts from the epic" bullet ("`simctl openurl` raises an OS
  confirmation gate on iOS 26; `XCUIApplication.open(_:)` does not") is
  imprecise as literally stated — both mechanisms raise the identical OS
  dialog on iOS 26.5; the real distinction is that XCUITest's own SpringBoard
  automation session can dismiss it and a bare shell command cannot. I wrote
  the docs to reflect what I actually observed rather than the brief's exact
  phrasing, per the task's instruction to fix discrepancies rather than
  match a claim that doesn't hold up.
- README's smoke command uses `xcrun simctl openurl booted ...`, which is
  ambiguous when more than one simulator is booted (an artifact of my test
  rig, not the normal single-simulator workflow) — not called out in the doc
  since it's not the documented/expected setup.
- `docs/LOCALIZATION.md` (the other "worked example" pointer in the brief)
  is written in Vietnamese and doesn't share `NETWORKING.md`'s structure, so
  I followed `NETWORKING.md` exclusively for `DEEPLINK.md`'s shape, per the
  brief's explicit Design Rationale bullet.


### Full-repo sweep for remaining stale governance counts

`git ls-files '*.md' | xargs grep -n "K1.K9\|K1.K10"` — every remaining
`K1–K9` hit, and the judgement call on each:

- **`.devtool/epic/android_super_app_template/*.md`** (2 files, 4 hits) —
  Android's own Konsist rule set, K1–K9, a **different governance system
  entirely** (Android's, not this repo's `ArchTests`). Not the same claim;
  correct as written; out of scope regardless of count.
- **`.devtool/epic/ios_deeplink_router/2026-09-10-ios-deeplink-router-design.md:48`**
  and **`.devtool/epic/ios_super_app_template/*.md`** (design doc, HLD
  en/vi, `task_12_ios_scanner_and_composition.md`,
  `task_15_ios_acceptance_e2e.md`) and
  **`.devtool/epic/settings_language_darkmode/*.md`** (design doc, HLD
  en/vi, `task_6_root_composition_app_wiring.md`) — all are **historical
  epic/task planning documents**, several from epics that completed before
  K10 existed. Correct as a record of what was true when written, the same
  category `docs/architecture/ARCHITECTURE.md:734` was already confirmed
  correct for (a citation of the *other* epic's spec section). Rewriting
  planning history after the fact would make these documents describe a
  future state they did not plan for; left untouched.
- **`.devtool/epic/ios_deeplink_router/bdd/task-7-feature-deeplink-declarations.md:125`**
  — "ArchTests K1/K9 stay green" — not a range claim at all; it names two
  specific rules (K1 and K9) that must individually stay green, unrelated
  to how many rules exist in total. Correct regardless of K10's existence;
  left untouched.
- **`.devtool/features/task_10_archtests_k10.md:132`** — "the K1–K9
  governance table K10 joins" — off-limits under this task's constraints
  (`.devtool/features/*.md`) regardless of content; also historically
  accurate as Task 10's own dispatch-time framing (before K10 was added).
  Left untouched on both grounds.
- **`docs/LOCALIZATION.md`**, **`docs/architecture/REFRESH_TOKEN.md`** —
  checked, no governance-count mentions at all.

No further live (non-historical, non-off-limits) governance-count staleness
found. Re-ran the cross-file link checker across all seven touched/checked
docs after this round — 0 broken links.
