---
id: "task_8_host_deeplink_wiring"
status: "done"
priority: "high"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T21:01:28+07:00"
completedAt: "2026-09-10T21:01:28+07:00"
labels: ["app", "composition", "deeplink", "tuist", "infrastructure"]
order: "a8"
---

# Task 8: Host Wiring — Composition, onOpenURL, URL Scheme, UserLoggedIn

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

Connect the engine to the real app. `App` is the only module that may know more
than one feature (**K6**), and it is where policy — what is gated, which tab a
route lands in — belongs.

**Deliverables**

1. **`DeepLinkComposition`** — builds the `DeepLinkRouter` over the existing
   `AppRouter`, installs the guard and resolver, registers every `RouteProvider`.
2. **`SessionDeepLinkGuard(session:redirectTo:)`** — reads
   `Core.SessionManaging.accessToken`. Returns `.allow` when `requiresAuth` is
   `false` or a token exists; otherwise `.redirect(to: redirectTo, retainPending: true)`
   when a redirect stack was configured, and `.deny` when it was not.
   **The template passes an empty `redirectTo`** — it ships no authentication
   feature. A consuming project supplies its login route in one line. This is the
   same wired-but-unexercised posture `AppComposition` already documents for
   `sessionManager` and `apiClient`.
3. **`ShellTabResolver`** — the single place the shell's tab layout is restated:
   `ScannerRoot → TabPlacement(tab: 1, isTabRoot: true)`,
   `SettingsRoot → TabPlacement(tab: 2, isTabRoot: true)`, everything else `nil`.
4. **`UserLoggedIn`** — new `AppEvent` in `Platform`, the symmetric counterpart of
   the existing `UserLoggedOut`. The host subscribes and calls `drainPending()`.
   No shipped feature publishes it; the publisher obligation is documented.
5. **Entry surface** — `.onOpenURL { composition.deepLinkRouter.open($0) }` on the
   root view, plus `CFBundleURLTypes` in `Info.plist` driven by a
   `DEEPLINK_SCHEME` build setting declared once in `Module.swift`
   (default `iosdigitalwallet`).

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleURLSchemes</key> <array><string>$(DEEPLINK_SCHEME)</string></array>
  </dict>
</array>
```

## Relevant Files & Context Pointers

- `App/Sources/Composition/DeepLinkComposition.swift` — **new** (guard + resolver + router)
- `App/Sources/Composition/AppComposition.swift` — expose `deepLinkRouter`; register providers inside the existing `// app:route-providers:begin/end` region
- `App/Sources/iOSDigitalWalletApp.swift` — add `.onOpenURL`
- `App/Resources/Info.plist` — `CFBundleURLTypes`
- `Tuist/ProjectDescriptionHelpers/Module.swift` — `DEEPLINK_SCHEME` base setting on `appTarget`
- `Packages/Platform/Sources/Platform/Events/AppEvent.swift` — add `UserLoggedIn`
- `Packages/Core/Sources/Core/Session/SessionManager.swift` — `SessionManaging.accessToken` (synchronous)
- `App/Tests/AppTests/AppCompositionTests.swift` — existing suite, extend

## Design Rationale

- **Policy in `App`, mechanism in `Platform` (invariant R1).** The guard is the
  only type that names a session; the resolver is the only type that knows the
  shell has three tabs. `Platform` sees neither concept.
- **`ShellTabResolver` restates the tab layout rather than importing it.**
  `ShellConfig` carries counts, not a route→tab map, and `Shell` must stay
  feature-blind — so the map lives in `App`, the one module allowed to know both
  sides. A Tier C test pins it against the real `ShellView` layout so the two
  cannot silently diverge.
- **`UserLoggedIn` with no in-template publisher is infrastructure, not dead
  code.** It matches the precedent already set in `AppComposition`, whose doc
  comment states `sessionManager` and `apiClient` are "ready for a
  network-backed feature to consume" while no shipped feature performs IO.
- **`DEEPLINK_SCHEME` in `Module.swift`.** Project rules designate that file as
  the single home for values like the deployment target; the scheme joins them so
  [Task 12](task_12_rename_script_scheme.md) has exactly one place to rewrite.
- **The router does not validate scheme or host.** iOS only delivers URLs for
  registered schemes and associated domains, so a second check would be redundant
  and would break Universal Links for consumers who enable them.
- Applicable skills in `.agents/skills/`: **`test-driven-development`**,
  and **`update-config`** is *not* applicable (this is Tuist/Info.plist, not
  Claude Code settings).

## TDD Checklist

- [ ] **RED**: `SessionDeepLinkGuard` — `requiresAuth: false` ⇒ `.allow`
      regardless of token · `requiresAuth: true` with a token ⇒ `.allow` ·
      without a token and an empty `redirectTo` ⇒ `.deny` · without a token and a
      configured `redirectTo` ⇒ `.redirect(retainPending: true)`.
- [ ] **RED**: `ShellTabResolver` — `SettingsRoot` ⇒ `(tab: 2, isTabRoot: true)` ·
      `ScannerRoot` ⇒ `(tab: 1, isTabRoot: true)` · an unknown route ⇒ `nil`.
- [ ] **RED**: `AppCompositionTests` — `deepLinkRouter` has one entry per pattern
      declared by the registered providers, and provider registration order
      matches `routeProviders`.
- [ ] **RED**: publishing `UserLoggedIn` on the composition's bus triggers
      `drainPending()` exactly once.
- [ ] **GREEN**: implement `DeepLinkComposition`, the guard, the resolver, the
      event, the `.onOpenURL` hook, the `Info.plist` entry and the build setting.
- [ ] **REFACTOR**: keep the provider-registration loop inside the marker region
      so Mason output stays mechanical; confirm `AppComposition` gained no
      feature-specific deep-link knowledge.

## Definition of Done

- [ ] `tuist generate --no-open && xcodebuild test` passes.
- [ ] `xcrun simctl openurl booted iosdigitalwallet://settings` switches to the
      Settings tab on a running simulator — pasted verification output.
- [ ] `swift test --package-path Packages/Platform` passes (`UserLoggedIn` added
      without breaking `EventModelTests`).
- [ ] `swift test --package-path ArchTests` passes — **K6** still green; `App`
      remains the sole multi-feature aggregator.
- [ ] `DEEPLINK_SCHEME` appears exactly once as a literal, in `Module.swift`.
- [ ] SwiftLint `--strict` and SwiftFormat `--lint` clean.

## Dependencies & Blockers

- Blocked by [Task 5](task_5_deeplink_router_engine.md) — needs the engine and
  both seam protocols.
- Blocked by [Task 7](task_7_feature_deeplink_declarations.md) — there is nothing
  to register until the features declare patterns.
- Blocks [Task 9](task_9_tier_c_acceptance_suite.md) and
  [Task 12](task_12_rename_script_scheme.md).

## References & Rollback

- BDD scenarios captured at implementation time: [task-8-host-deeplink-wiring.md](../epic/ios_deeplink_router/bdd/task-8-host-deeplink-wiring.md)
- Source Spec §4.8 (host wiring), §4.9 (`UserLoggedIn`), §4.10 (scheme and
  rename script).
- `App/Sources/Composition/NetworkComposition.swift` — the existing precedent for
  a focused composition helper.
- **Rollback**: remove `.onOpenURL`, the `CFBundleURLTypes` block and
  `DeepLinkComposition`. The engine stays in `Platform`, dormant and harmless;
  no feature code changes.
