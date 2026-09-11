# Deep Link Architecture

*(iOS Native edition)*

This document describes the deep-link subsystem: how an incoming `URL` —
custom scheme or Universal Link — becomes a navigation stack pushed on
`Platform.AppRouter`. It follows [`NETWORKING.md`](NETWORKING.md)'s shape
(problem, contract, worked example, governance, gaps) rather than inventing
its own. The **registered, OS-delivered** URL scheme is
**`iosdigitalwallet://`** (`Tuist/ProjectDescriptionHelpers/Module.swift`'s
`Module.deepLinkScheme`) — the only scheme `CFBundleURLTypes` claims, and
the only one `xcrun simctl openurl` or a tapped link can actually hand this
app. `app://` shows up widely across this repo's own doc comments and test
suites instead — `DeepLink.swift`'s type doc comment uses it as the worked
example throughout, and so do `DeepLinkFlowTests`, both feature
`*DeepLinkTests` suites, and most of `PlatformTests` — because `DeepLink` /
`DeepLinkPattern` / `DeepLinkRouter` never inspect scheme or host beyond the
custom-vs-web split in [§1](#1-the-url-grammar); `app://` is illustrative
shorthand there, never something the OS delivers.

> [!IMPORTANT]
> **Three obligations this subsystem hands to a consuming project.** Each is
> invisible until it silently does not work — no test in this repo can catch
> any of them, because each one is a decision only a consuming project's own
> code makes:
>
> 1. **A guard's redirect target must itself be reachable without auth.**
>    `SessionDeepLinkGuard` (or your replacement) evaluates its own
>    `redirectTo` stack once, with `requiresAuth: false`. If that stack would
>    itself be denied or redirected, the router reports `.denied` instead of
>    looping — see [§3](#3-guard-and-tab-resolver-contracts).
> 2. **`UserLoggedIn` must be published *after* the access token is written
>    to `SessionManaging`, never before.** See [§4](#4-pending-links-and-replay).
> 3. **A feature that owns a tab must add a `TabPlacement` for its root
>    route(s) to the host's `TabResolver`** (`ShellTabResolver` in this
>    template). See [§2](#2-declaring-deep-links-from-a-feature) and
>    [§3](#3-guard-and-tab-resolver-contracts).

---

## Table of Contents

- [1. The URL Grammar](#1-the-url-grammar)
- [2. Declaring Deep Links From a Feature](#2-declaring-deep-links-from-a-feature)
- [3. Guard and Tab-Resolver Contracts](#3-guard-and-tab-resolver-contracts)
- [4. Pending Links and Replay](#4-pending-links-and-replay)
- [5. The Gating Asymmetry](#5-the-gating-asymmetry)
- [6. Enabling Universal Links](#6-enabling-universal-links)
- [7. Governance: ArchTests K10](#7-governance-archtests-k10)
- [8. What This Template Deliberately Does Not Ship](#8-what-this-template-deliberately-does-not-ship)
- [References](#references)

---

## 1. The URL Grammar

Two types do all the parsing. `DeepLink` (`Packages/Platform/Sources/Platform/Navigation/DeepLink/DeepLink.swift`)
normalises a raw `URL` into segments + query; `DeepLinkPattern`
(`.../DeepLink/DeepLinkPattern.swift`) matches a declared pattern string
against a normalised `DeepLink`. Neither does the other's job.

### Normalisation (`DeepLink.init?(url:)`)

| Input shape | Rule |
|---|---|
| Custom scheme — `iosdigitalwallet://settings/language` | host is prepended as the first segment ⇒ `["settings", "language"]` |
| Universal Link — `https://example.com/settings/language` | host is discarded ⇒ `["settings", "language"]` |
| Trailing / doubled slashes | empty path segments are removed |
| Case | segments are stored verbatim, never lowercased |
| Percent-encoding | decoded **per segment**, so a percent-encoded slash (`%2F`) stays inside its segment instead of splitting it (RFC 3986 §3.3) |
| Duplicate query keys | the **last** occurrence wins — never silently ignored |
| Query item with no value (`?flag`) | maps to `""` |
| `URLComponents(url:resolvingAgainstBaseURL: false)` fails to parse | `DeepLink.init?` returns `nil` |

Verified against the built `Platform` package (see [Verification](#verification-record) below):

```swift
DeepLink(url: URL(string: "iosdigitalwallet://settings/language")!)!.path
// == ["settings", "language"]           — custom scheme: host is segment 0

DeepLink(url: URL(string: "https://example.com/settings/language")!)!.path
// == ["settings", "language"]           — https: host discarded

DeepLink(url: URL(string: "iosdigitalwallet://settings?tab=a&tab=b")!)!.query["tab"]
// == "b"                                — duplicate query key, last wins
```

### Pattern syntax (`DeepLinkPattern.init(_:)`)

| Rule | Behaviour |
|---|---|
| Leading `/` | optional; stripped |
| A segment starting with `:` | a parameter; the rest of the segment is its name |
| Any other segment | a literal |
| Segment count | must match the link's path **exactly** — no wildcards, no globbing, no optional segments |
| Literal comparison | case-insensitive (both sides lowercased) |
| Parameter values | keep their original case, verbatim from `link.path` |
| `"/"` or `""` | zero segments; matches a link whose `path` is empty |

Grammar enforced at build time by ArchTests **K10.3** (literal
`^[a-z0-9-]+$`, parameter `^:[a-z][a-zA-Z0-9]*$`) and **K10.5** (no repeated
parameter name in one pattern) — see [§7](#7-governance-archtests-k10).

### Parameter precedence: path beats query

`DeepLinkPattern.match(_:)` merges captured path parameters over the link's
query items — a path parameter **always wins** a name collision, because a
path segment is structural (authored by the pattern) while a query item
arrives from outside the app and must never be able to shadow it:

```swift
let pattern = DeepLinkPattern("/tx/:id")
let link = DeepLink(url: URL(string: "iosdigitalwallet://tx/123?id=999")!)!
pattern.match(link)!["id"]
// == "123", not "999"                   — path parameter wins
```

Without this rule, `/tx/:id?id=evil` would be ambiguous about which `id` a
handler receives.

---

## 2. Declaring Deep Links From a Feature

`Platform.RouteProvider` carries one extra requirement beyond `canHandle` /
`destination(for:)`:

```swift
@MainActor
var deepLinks: [DeepLinkRoute] { get }   // defaults to [] — opt-in, source-compatible
```

Each `DeepLinkRoute("/pattern", requiresAuth: false) { params in [...] }`
pairs a pattern with a `build` closure that turns captured
`DeepLinkParams` into the **parent-to-child navigation stack** to push.

**The parent-chain convention.** The first element of the array `build`
returns is this feature's own tab-root route. `DeepLinkRouter` drops that
first element only when the tab it resolves to is the same tab that route
claims as its root (`TabPlacement.isTabRoot`) — otherwise the root screen
would be pushed a second time on top of itself. This is why every declared
route's stack starts with the feature's root even when the deep link targets
a child screen: it is what lets back-navigation from a deep-linked child land
inside the app, never outside it.

### A real, shipped example

This is `ScannerRouteProvider.deepLinks`
(`Features/Scanner/Sources/Scanner/Presentation/ScannerRouteProvider.swift`),
copy-pasteable as-is — it is part of the repo's passing baseline (Scanner
46/46 tests), not illustrative pseudocode:

```swift
public var deepLinks: [DeepLinkRoute] {
    [
        DeepLinkRoute("/scanner") { _ in [AppRoutes.ScannerRoot()] },
        DeepLinkRoute("/scanner/result/:code") { params in
            // A pattern declaring `:code` cannot match a link missing that
            // segment, so `params["code"]` is always present here — `?? ""`
            // is defensive only, never a reachable fallback.
            [AppRoutes.ScannerRoot(), ScannerResultRoute(code: params["code"] ?? "")]
        },
    ]
}
```

Two patterns, one tab: `/scanner` resolves to the tab root alone; `/scanner/result/:code`
resolves to `[root, child]`, with `ScannerRoot()` dropped by the router only
when the stack lands on Scanner's own tab (the ordinary case). The template's
full map:

| Pattern | Stack | `requiresAuth` | Demonstrates |
|---|---|---|---|
| `/settings` | `[SettingsRoot]` | `false` | a tab root, first element dropped |
| `/scanner` | `[ScannerRoot]` | `false` | the second tab root |
| `/scanner/result/:code` | `[ScannerRoot, ScannerResultRoute(code:)]` | `false` | multi-level stack + a path parameter |

No shipped route sets `requiresAuth: true` — see [§8](#8-what-this-template-deliberately-does-not-ship).

### Registering a route that crosses features (K10.2)

A cross-feature entry point — anything declared in
`Platform/Navigation/AppRoutes.swift` — **must** be referenced by at least
one `DeepLinkRoute.build` body, enforced by ArchTests **K10.2**. A
feature-private route (never promoted to `AppRoutes`) carries no such
obligation; K9 and K10.2 both key off the same "is this in `AppRoutes`?"
question.

### Scaffolding: what `mason make ios_mvi_feature` also touches

`ios_mvi_feature`'s generated `RouteProvider.swift` already declares this
feature's root pattern; the printed checklist tells you to register the
`TabPlacement` if the feature owns a tab. What the checklist does **not**
mention — but the brick genuinely touches, confirmed by generating two
throwaway features and diffing `git status --porcelain` before/after
(recorded in Task 11's report) — is eight more files:

- `App/Resources/Localizable.xcstrings` and
  `Packages/Platform/Resources/Localizable.xcstrings` (merged catalogues, 2
  files)
- `App/Resources/backend_translations/{en,en_US,vi,vi_VN}.json` (four files)
- `Packages/Platform/Sources/Platform/Localization/Translations.generated.swift`
  (1 file)
- `Tuist/Package.resolved` (1 file)

All eight return to exactly their pre-generation baseline when the feature
is removed with `ios_remove_feature` — `git diff --stat` over all eight was
empty in the same verification pass — so this is a **disclosure** gap, not a
correctness one: nothing is orphaned, but a developer reviewing the
resulting diff should not be surprised by eight files they did not expect to
see touched by "add a feature."

---

## 3. Guard and Tab-Resolver Contracts

Two optional seams, both `@MainActor`, both consulted only by
`DeepLinkRouter`:

```swift
public protocol DeepLinkGuard {
    func evaluate(_ stack: [any AppRoute], requiresAuth: Bool) -> GuardDecision
}
public enum GuardDecision {
    case allow
    case redirect(to: [any AppRoute], retainPending: Bool)
    case deny
}

public protocol TabResolver {
    func placement(for route: any AppRoute) -> TabPlacement?
}
public struct TabPlacement: Equatable, Sendable {
    public let tab: Int
    public let isTabRoot: Bool
}
```

`Platform` never learns what "auth" means (invariant R1) — the guard
receives only a `Bool` the feature declared (`DeepLinkRoute.requiresAuth`)
and a stack of opaque routes, and answers allow / redirect / deny. Both
protocols are `nil`-able at `DeepLinkRouter.init`: `nil` guard means
allow-all, `nil` resolver means "always use the currently selected tab", and
a `nil` return from `placement(for:)` means the same thing per-route — this
is the correct outcome for a feature-private route no tab claims, not a
failure. (Tab 0, `HomeStubView`, is Shell-owned and maps to no `AppRoute` at
all — `ShellTabResolver` returning `nil` when asked about it would be
correct for the same reason, though in practice nothing ever asks it about
tab 0's content since nothing deep-links there.)

### The redirect-target invariant

> A redirect target must itself be reachable without authentication.

`DeepLinkRouter` evaluates `redirectStack` through the **same** guard, once,
with `requiresAuth: false`, and never recursively. If the guard's answer for
its own redirect target is anything other than `.allow`, the router reports
`.denied` instead of looping forever chasing further redirects. This is
obligation **1** from the top of this document: whatever the consuming
project points `redirectTo` at (a sign-in screen, typically) must not itself
require the very session state the redirect exists to obtain.

### The host's implementation — a real, shipped example

`App/Sources/Composition/DeepLinkComposition.swift`, part of the passing
baseline (the `App` target build):

```swift
struct SessionDeepLinkGuard: DeepLinkGuard {
    private let session: any SessionManaging
    private let redirectTo: [any AppRoute]

    init(session: any SessionManaging, redirectTo: [any AppRoute]) {
        self.session = session
        self.redirectTo = redirectTo
    }

    func evaluate(_: [any AppRoute], requiresAuth: Bool) -> GuardDecision {
        guard requiresAuth else { return .allow }
        guard session.accessToken == nil else { return .allow }
        guard !redirectTo.isEmpty else { return .deny }
        return .redirect(to: redirectTo, retainPending: true)
    }
}

struct ShellTabResolver: TabResolver {
    func placement(for route: any AppRoute) -> Platform.TabPlacement? {
        switch route {
        case is AppRoutes.ScannerRoot:
            Platform.TabPlacement(tab: 1, isTabRoot: true)
        case is AppRoutes.SettingsRoot:
            Platform.TabPlacement(tab: 2, isTabRoot: true)
        default:
            nil
        }
    }
}
```

The template wires `SessionDeepLinkGuard(session: sessionManager, redirectTo: [])`
— an intentionally empty redirect target, because the template ships no
authentication feature. A consuming project supplies its own sign-in route
in one line: `redirectTo: [AppRoutes.SignInRoot()]`. `ShellTabResolver` is
"the one module allowed to know both the shell's tab layout and the
features' routes" — adding a feature that owns a tab means adding one `case`
here (obligation **3**).

### What your own tests can (and cannot) prove

`AppRouter.destination(for:)` resolves through `providers.first(where: { $0.canHandle(route) })`
— first match wins. **If a real `RouteProvider` is already registered for a
route, a test-registered spy provider is never consulted for it**, because
the real provider's `canHandle` matches first. A test that swaps in a spy to
assert "my new route renders something" only proves that for a route no
already-registered provider claims. The one guard against a genuinely blank
screen for an *already-claimed* route is the UI test
(`App/UITests/DeepLinkOpenURLUITests.swift`), which drives the real,
fully-composed app through the OS. Know which one your own test is actually
exercising before trusting it as proof against D3 (the blank-screen
failure).

---

## 4. Pending Links and Replay

A link a guard redirects with `retainPending: true` is parked — **exactly
one**, no TTL. A newer redirected link always supersedes an older one,
matching "go here now" semantics; there is no queue. `DeepLinkRouter.drainPending()`
re-attempts the parked stack through the identical guard + navigate path
`open(_:)` uses, and is a no-op when nothing is pending.

### The consumer's replay obligation — and its ordering requirement

The host subscribes to `UserLoggedIn` and calls `drainPending()` when it
fires (`DeepLinkReplayObserver` in `DeepLinkComposition.swift`, wired for
the process lifetime). **No shipped feature publishes `UserLoggedIn`** — the
template ships no authentication feature — so a consuming project's own
sign-in flow must publish it. `AppEvent.swift`'s doc comment says to publish
it "when sign-in succeeds," but that is incomplete on its own:

> **The access token must be written to `SessionManaging` *before*
> `UserLoggedIn` is published — never after, never concurrently.**
> `AppEventBus` delivery is deferred one main-queue turn (`PassthroughSubject`,
> `.receive(on: DispatchQueue.main)`), and `SessionDeepLinkGuard` reads
> `session.accessToken` **live**, synchronously, at the moment `drainPending()`
> calls it — not a snapshot taken when `UserLoggedIn` was published. Publish
> before writing the token and `drainPending()` re-evaluates against a
> session that still looks logged-out: the guard redirects again, the
> pending link is re-retained (recoverable — nothing is lost), but the user
> is left sitting on the redirect screen with no indication anything went
> wrong. No test in this repo can catch a consumer getting this backwards;
> it is the one obligation handed entirely to the consuming project.

```swift
// Correct ordering, in a consuming project's sign-in completion handler:
func onSignInSucceeded(
    sessionManager: any SessionManaging,
    eventBus: AppEventBus,
    accessToken: String,
    refreshToken: String?
) {
    // 1. Write the token first — SessionDeepLinkGuard reads the session live.
    sessionManager.update(accessToken: accessToken, refreshToken: refreshToken)
    // 2. Publish second — drainPending() must see a session that already has a token.
    eventBus.publish(UserLoggedIn())
}
```

(Typechecked against the built `Platform` + `Core` modules — see
[Verification](#verification-record).)

---

## 5. The Gating Asymmetry

**The guard runs on deep-link entry only.** `DeepLinkRouter.resolve(stack:requiresAuth:)`
is the only call site that ever consults `DeepLinkGuard`. Tapping a tab bar
item goes through `ShellViewModel.selectTab(_:)`
(`Packages/Shell/Sources/Shell/ShellViewModel.swift`), which reduces state,
calls `router.switchTab(_:)`, and publishes `ShellTabVisibilityChanged` —
**it never calls `DeepLinkGuard.evaluate`, and cannot, because `Shell` is
feature-blind and holds no reference to one.** A route reachable by tapping
a tab is reachable by tapping it regardless of what that route's
`DeepLinkRoute.requiresAuth` says; the flag only ever gates URL-triggered
entry.

This is deliberate, not an oversight: gating manual tab navigation is a
product decision (does the tab itself require a session, or only some
content inside it?) that this subsystem cannot make on a consuming project's
behalf. If your project needs symmetric gating, the seam to add it at is
**`ShellViewModel`**, not `DeepLinkRouter` or `DeepLinkGuard`.

---

## 6. Enabling Universal Links

The template ships the custom-scheme half of the contract
(`CFBundleURLTypes` / `DEEPLINK_SCHEME` in `Module.swift`) and deliberately
nothing else — see [§8](#8-what-this-template-deliberately-does-not-ship)
for why. A consuming project that owns a real domain enables Universal Links
in three steps, and **needs no change to `DeepLinkRouter`, `DeepLinkPattern`,
or any `RouteProvider.deepLinks`** — `DeepLink.init?(url:)` already
normalises `https://` the same shape a custom-scheme URL produces (host
discarded instead of prepended; see [§1](#1-the-url-grammar)), so every
existing pattern matches an `https` link exactly as it matches
`iosdigitalwallet://`.

1. **Add the Associated Domains entitlement** (`applinks:example.com`) to
   the app target — requires an Apple Developer Program team, which this
   template does not assume.
2. **Host an `apple-app-site-association` file** at
   `https://example.com/.well-known/apple-app-site-association`, naming the
   app's Team ID + bundle identifier and the paths it claims — requires a
   real, owned domain.
3. **Forward `onContinueUserActivity` into the same `open(_:)` `.onOpenURL`
   already calls**, in `App/Sources/<AppName>App.swift`:

```swift
WindowGroup {
    RootView(composition: composition)
        .onOpenURL { url in
            composition.deepLinkRouter.open(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            composition.deepLinkRouter.open(url)
        }
        .onChange(of: scenePhase) { newPhase in
            lifecycleObserver.handle(newPhase)
        }
}
```

(Typechecked against the real `DeepLinkRouter` type — see
[Verification](#verification-record).) Both handlers call the identical
`deepLinkRouter.open(_:)` that `DeepLinkRulesTests`' K10.4 already pins
`.onOpenURL` to; there is exactly one entry point into the resolution table
regardless of which OS mechanism delivered the `URL`.

---

## 7. Governance: ArchTests K10

`swift test --package-path ArchTests` — `ArchTests/Tests/ArchTests/DeepLinkRulesTests.swift`.
The repo's stated philosophy is *enforce structurally, do not rely on
discipline*, applied to `DeepLinkRoute` declarations, which are scattered
across every feature package and therefore drift silently without a
structural check. **Six rules**, not three — the rule grew twice during the
epic:

| Rule | Rejects |
|---|---|
| **K10.1** | two `DeepLinkRoute` declarations anywhere in the repo sharing one pattern string (duplicates would silently shadow each other — the router's first-match-wins contract is only safe because this holds) |
| **K10.2** | an `AppRoutes` member no `DeepLinkRoute.build` body ever references (a cross-feature entry point unreachable by URL) |
| **K10.3** | a malformed pattern segment — literal not matching `^[a-z0-9-]+$`, parameter not matching `^:[a-z][a-zA-Z0-9]*$` |
| **K10.4** | the app entry point *not* wiring `.onOpenURL` to `deepLinkRouter.open` — a source-text pin, deliberately not an AST rule, standing in for the behavioural coverage only a UI test can give |
| **K10.5** | a single pattern declaring the same parameter name twice (`match` would resolve the repeat last-wins, silently dropping a captured value) |
| **K10.6** | any `DeepLinkRoute(...)` call whose first argument is not a static string literal — closes the blind spot where an interpolated / `let`-bound / parameter-passed pattern would otherwise vanish from K10.1, K10.3 **and** K10.5 simultaneously, in the dangerous direction |

K10.1/K10.2/K10.3/K10.5 all walk one shared AST pass,
`SyntaxScanner.deepLinkRouteCalls(in:)`, over every `.swift` file under
`Features/*/Sources`, `Packages/*/Sources` and `App/Sources`. **`ArchTests`
deliberately does not depend on `Platform`** (it is a standalone
swift-syntax package — see `docs/architecture/ARCHITECTURE.md` §VI), so
K10.3 and K10.5 cannot call `DeepLinkPattern.init` to get `segments`; they
re-derive the identical `split(separator: "/", omittingEmptySubsequences: true)`
split locally, in `DeepLinkRulesTests.patternSegments(_:)`. **There are two
hand-maintained copies of "how a pattern breaks into segments," with nothing
keeping them in sync** — if `DeepLinkPattern.init` ever changes
`omittingEmptySubsequences`, or adds case-folding or percent-decoding before
the split, `patternSegments(_:)` must be updated to match or K10.3/K10.5
drift silently. (This duplication — and the fact that `DeepLinkPattern.swift`'s
doc comment used to claim ArchTests reused its parsing directly, which it
does not — is recorded in that file's doc comment as of this task.)

See `ARCHITECTURE.md` §VI for K10 alongside K1–K9 in the repo's single
governance table.

---

## 8. What This Template Deliberately Does Not Ship

So a reader does not mistake an intentional boundary for an unfinished one:

- **No authentication feature.** `Features/` ships only `Settings` (real)
  and `Scanner` (stub); neither needs a session. `SessionDeepLinkGuard` is
  wired with `redirectTo: []` — the same "wired but unexercised" posture
  `AppComposition` already documents for `sessionManager` and `apiClient`.
- **No route sets `requiresAuth: true`.** Shipping one would either deny the
  template's own demo link on a fresh clone or require inventing product
  domain the template is supposed to stay neutral of. The `requiresAuth`
  flag's behaviour (redirect, pending storage, replay, deny) is covered
  instead by `PlatformTests` with a fake guard and `AppTests` with a
  test-injected one.
- **No Universal Links entitlement, AASA file, or `onContinueUserActivity`
  forwarding.** All three require a real, owned domain and (for Associated
  Domains) an Apple Developer Program team — see [§6](#6-enabling-universal-links)
  for the three steps a consuming project takes to add them; no code in
  `DeepLinkRouter` changes.

---

## Verification Record

Every code sample above was either (a) copied verbatim from source that is
already part of this repo's passing test/build baseline, or (b) compiled /
run independently for this task:

- The `ScannerRouteProvider.deepLinks`, `SessionDeepLinkGuard`, and
  `ShellTabResolver` samples ([§2](#2-declaring-deep-links-from-a-feature),
  [§3](#3-guard-and-tab-resolver-contracts)) are quoted verbatim from
  `Features/Scanner/Sources/Scanner/Presentation/ScannerRouteProvider.swift`
  and `App/Sources/Composition/DeepLinkComposition.swift` — both compile as
  part of `xcodebuild build -workspace iOSDigitalWallet.xcworkspace -scheme iOSDigitalWallet`,
  run for this task (`** BUILD SUCCEEDED **`).
- The [§1](#1-the-url-grammar) grammar claims and the path-beats-query
  precedence example were not just typechecked but **executed**: a scratch
  SwiftPM executable depending on the real `Packages/Platform` (via a local
  path dependency, no repo file touched) asserted four grammar facts (custom
  scheme host-prepending, `https` host-discarding, duplicate-query
  last-wins, path-beats-query) plus two parent-chain stack-building facts
  (stack count, captured-parameter propagation) against the actual compiled
  types — six assertions, all printing `PASS`.
- The [§4](#4-pending-links-and-replay) `UserLoggedIn`-ordering sample and
  the [§6](#6-enabling-universal-links) `onContinueUserActivity` sample were
  typechecked (`swiftc -typecheck`) against the built `Platform` / `Core`
  frameworks from that same `xcodebuild` run; both typecheck cleanly.
- The `xcrun simctl openurl` smoke command in `README.md` was executed
  against a booted iPhone 17 simulator with this build installed. See
  `README.md`'s own note on the iOS 26 confirmation dialog it can raise.

---

## References

### In-repo
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — the module map, the `ArchTests`
  K1–K10 governance table, and `AnyAppRoute` in the navigation section.
- [`NETWORKING.md`](NETWORKING.md) — the structural precedent this document
  follows.
- `Packages/Platform/Sources/Platform/Navigation/DeepLink/` — `DeepLink.swift`,
  `DeepLinkPattern.swift`, `DeepLinkRoute.swift`, `DeepLinkGuard.swift`,
  `DeepLinkRouter.swift`, `TabResolver.swift` — every type this document
  describes, each with its own doc comment.
- `App/Sources/Composition/DeepLinkComposition.swift` — the host's
  `SessionDeepLinkGuard` / `ShellTabResolver` / `DeepLinkReplayObserver`.
- `App/UITests/DeepLinkOpenURLUITests.swift` — the OS-level smoke test; its
  own doc comment records the iOS 26 confirmation-dialog finding in detail.
- `ArchTests/Tests/ArchTests/DeepLinkRulesTests.swift` — K10.1–K10.6.

### Epic design
- [`../../.devtool/epic/ios_deeplink_router/2026-09-10-ios-deeplink-router-design.md`](../../.devtool/epic/ios_deeplink_router/2026-09-10-ios-deeplink-router-design.md) —
  the Source Spec: §4 the full contract, §6 the governing failure principle,
  §7 the K10 rule table.
- [`../../.devtool/epic/ios_deeplink_router/ios_deeplink_router.en.md`](../../.devtool/epic/ios_deeplink_router/ios_deeplink_router.en.md) — the HLD.
