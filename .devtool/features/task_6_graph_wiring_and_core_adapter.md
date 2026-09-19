---
id: "task_6_graph_wiring_and_core_adapter"
status: "todo"
priority: "high"
assignee: null
epic: "pulse_logger"
dueDate: null
created: "2026-09-19T04:47:44+07:00"
modified: "2026-09-19T04:47:44+07:00"
completedAt: null
labels: ["architecture", "tuist", "governance", "backward-compatibility"]
order: "a6"
---

# Task 6: Graph Wiring Across Template Modes, `Core.Logger` Adapter & Mason Brick

Epic Reference: [pulse_logger](../epic/pulse_logger/pulse_logger.en.md) · BDD: [bdd_scenarios.md](../epic/pulse_logger/bdd_scenarios.md) Cross-cutting

## Requirement Analysis

Bring `Packages/AppLogging` into the buildable project graph and swap the composition root onto
it **without touching any of the 22 downstream call sites** found by Check 1. This is the first task
whose changes alter app behaviour.

The source spec described this as "add to `Tuist/Package.swift` and `Project.swift`". The Stage-2
audit found that insufficient in four separate ways, all of which fail silently rather than loudly:

1. **`Tuist/Package.swift` carries two dependency lists** — the `// tuist:packages:begin/end` marker
   region for `enterprise`, and a hand-written array for `lean`. Editing only the marker region
   leaves lean mode unable to resolve the package.
2. **`Project.swift` likewise has separate `enterprise` and `lean` target dependency lists.**
3. **`ArchTests` K7 hard-codes its sibling list** — `HostRulesTests.coreSiblings` is
   `["Framework", "Network", "AppUIKit", "Platform"]`. Without the new name, `Core` could import the
   logging package and the gate would stay green.
4. **The Mason brick injects `Core.Logger`** — `bricks/ios_mvi_feature/__brick__/` appeared in the
   Check 1 blast radius. Every feature generated after this epic would otherwise be born on the old
   seam.

## Relevant Files & Context Pointers

- `Tuist/Package.swift` — modify **both** the marker region and the `lean` array
- `Project.swift` — modify **both** the `enterprise` and `lean` dependency lists
- `Workspace.swift` — verify the package is included; modify if not
- `ArchTests/Tests/ArchTests/HostRulesTests.swift` — add `"AppLogging"` to `coreSiblings`
- `App/Sources/Composition/LoggingComposition.swift` — create: builds `LogManagerImpl`, registers
  `OSLogAppender`, calls `AppLogger.initialize` and `LoggingSystem.bootstrap` exactly once
- `App/Sources/Composition/CoreLoggerAdapter.swift` — create
- `App/Sources/Composition/AppComposition.swift` — modify: replace `ConsoleLogger()` with the adapter
- `App/Sources/Composition/ConsoleLogger.swift` — **retain unchanged** until the DoD is met
- `bricks/ios_mvi_feature/__brick__/**` — modify
- `docs/architecture/ARCHITECTURE.md` — modify: module map table and the Layer 3 graph
- `App/Tests/AppTests/**` — extend composition tests

## Design Rationale

- **The adapter is the whole backward-compatibility story.** `Core.Logger` is threaded through
  `CacheStore`, `SecureCacheStore`, `SafeExecution`, `DeepLinkRouter`, `APIClient`,
  `SettingsRepositoryImpl` and every generated repository — 22 files. `CoreLoggerAdapter`
  implements `Core.Logger`'s three methods over `LoggerProtocol`, so not one of them changes. Task 2's
  naming decision (`debug` / `info` / `error` rather than `d` / `i` / `e`) makes this a direct 1:1
  mapping (HLD D2).
- **`file` / `function` / `line` are preserved as metadata**, not discarded — `Core.Logger` passes
  them at every call site and losing them would be a regression against `ConsoleLogger`.
- **`ConsoleLogger.swift` stays on disk through this task.** It is the documented rollback: reverting
  one line in `AppComposition` restores the old behaviour. Delete it only once the composition tests
  prove the adapter, and say so in the commit body.
- **Single bootstrap point.** `LoggingSystem.bootstrap` traps if called twice. `LoggingComposition`
  owns the one call; `AppComposition` must not call it, and `App/Tests` must not either.
- **Doc sync is part of this task, not a follow-up.** `ARCHITECTURE.md` §2's module map and §3's
  Layer 3 graph become factually wrong the moment the package lands. Leaving them stale would be a
  divergence the lifecycle requires syncing before the next task starts.

Applicable skills: `architecture-audit`, `code-health-audit`; Tuist (`tuist generate`); `ArchTests`.

## Impact Analysis & Blast Radius

- **Target symbols**: `CoreLoggerAdapter`, `LoggingComposition`, `AppComposition.init`,
  `HostRulesTests.coreSiblings`, both Tuist manifests, the brick templates.
- **Downstream callers**: all 22 files from Check 1 — reached **transitively and unmodified** through
  the adapter. If any of them needs editing, the adapter is wrong; stop and fix the adapter.
- **Cross-platform bridges**: none.
- **Coverage threshold**: adapter ≥ 90% line; composition wiring asserted by `App/Tests`.
- **Template modes**: `enterprise` and `lean` both change. `plugin` is untouched and must be
  verified unaffected.

## BDD Scenarios & Acceptance Criteria

### BDD SCENARIOS

Authoritative copies in [bdd_scenarios.md](../epic/pulse_logger/bdd_scenarios.md). This task implements the Cross-cutting
scenarios "Core call sites keep working through the compatibility adapter", "The architecture gate
accepts the new package" and "Every template mode still generates and builds", plus:

```gherkin
[Tier C - Integration]
Scenario: The composition root bootstraps logging exactly once
  Given the host app composed through AppComposition
  When the composition is built twice in the same test process
  Then LoggingSystem.bootstrap is invoked exactly once
  And no trap occurs
```

```gherkin
[Tier A - Unit]
Scenario: Call-site provenance survives the adapter
  Given a CoreLoggerAdapter over a spy logger
  When debug("m", file: "F.swift", function: "f()", line: 42) is called
  Then the dispatched LogRecord level is .debug and message is "m"
  And its metadata records file "F.swift", function "f()" and line "42"
```

```gherkin
[Tier B - Governance]
Scenario: K7 now guards the logging package
  Given an injected `import AppLogging` in a Packages/Core source file
  When swift test --package-path ArchTests is executed
  Then testK7_CoreSourcesImportNoSiblingInfraModule fails and names the offending file
  # RED-then-GREEN: prove the rule fires before trusting it, per the repo's ArchTests convention.
```

```gherkin
[Tier B - Governance]
Scenario: A newly generated feature is born on the new logging seam
  Given the ios_mvi_feature brick
  When a feature is generated from it
  Then the generated sources compile against the current logging contract
  And no generated file references a removed symbol
```

## Test & Verification Checklist

- [ ] **RED** — write the adapter and composition tests, and inject the K7 violation to prove the
      updated rule fires before reverting it.
- [ ] **GREEN** — implement the adapter and `LoggingComposition`; wire both template modes in both
      manifests; update `coreSiblings`; update the brick.
- [ ] **REFACTOR** — `swiftformat`; `swiftlint --strict`;
      `bash scripts/check_module_boundaries.sh`.
- [ ] **Tier B** — `swift test --package-path ArchTests` green with the injection reverted.
- [ ] **Tier C** — `tuist generate --no-open` then
      `xcodebuild test -workspace iOSDigitalWallet.xcworkspace -scheme iOSDigitalWallet -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO`.
- [ ] **Mode sweep** — `./scripts/configure_mode.sh lean && tuist generate --no-open`, then restore
      `enterprise`. Confirm `plugin` mode is untouched by the diff.

## Definition of Done (DoD)

- Both `enterprise` and `lean` generate and build; `plugin` provably unaffected.
- `ArchTests` green, with K7 shown to fire on an injected violation and then reverted.
- Not one of the 22 downstream call sites was edited.
- `file` / `function` / `line` preserved through the adapter.
- `LoggingSystem.bootstrap` called exactly once per process.
- `ARCHITECTURE.md` module map and Layer 3 graph updated in this commit.
- Brick updated; a generated feature compiles.
- `ConsoleLogger.swift` removed **only after** the composition tests pass, and its removal noted in
  the commit body.
- SwiftLint, SwiftFormat and `check_module_boundaries.sh` all clean.

## Dependencies & Blockers

- Blocked by: [Task 4](task_4_oslog_appender.md), [Task 5](task_5_swift_log_bridge.md).
- Blocks: [Task 7](task_7_trace_context_seam_and_interceptor.md),
  [Task 8](task_8_pulse_appender_and_session_capture.md).

## References & Rollback

- HLD §3.1 — the unowned-item table listing the lean mode, K7 and brick gaps
- Tuist marker-region convention — `CLAUDE.md` "Build & configuration"
- Rollback: revert `AppComposition.swift` to `ConsoleLogger()`. The package stays in the graph as
  dead code rather than a breaking change, because every call site still speaks `Core.Logger`.
