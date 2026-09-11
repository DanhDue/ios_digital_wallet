# BDD Scenarios — Task 10: ArchTests K10 Governance Rules

Captured from the implementer's QA pass at implementation time (2026-09-11).
Historical record of what was analysed — including partitions deliberately
excluded. The executable form is the ArchTests suite; see the task's Relevant
Files. Task: [task_10_archtests_k10](../../../features/task_10_archtests_k10.md)

### BDD SCENARIOS

```gherkin
Feature: K10.1 — no two DeepLinkRoute declarations share a pattern string

  Scenario: Zero declarations
    Given no DeepLinkRoute(...) call sites exist in production sources
    Then K10.1 passes trivially

  Scenario: One declaration
    Given exactly one DeepLinkRoute("/settings") { ... } call site
    Then K10.1 passes

  Scenario: Two distinct patterns
    Given DeepLinkRoute("/settings") and DeepLinkRoute("/scanner")
    Then K10.1 passes

  Scenario: Two identical patterns in the same file
    Given a file declaring DeepLinkRoute("/scanner") twice
    Then K10.1 fails, naming that one file twice and the pattern `/scanner`

  Scenario: Two identical patterns across different packages/features
    Given ScannerRouteProvider.swift and SettingsRouteProvider.swift both
      declare DeepLinkRoute("/settings")
    Then K10.1 fails, naming both files and the pattern `/settings`

Feature: K10.2 — every AppRoutes member is reachable by a DeepLinkRoute.build body

  Scenario: An AppRoutes member referenced in a build body
    Given AppRoutes.SettingsRoot is declared and
      DeepLinkRoute("/settings") { _ in [AppRoutes.SettingsRoot()] } exists
    Then K10.2 passes for SettingsRoot

  Scenario: Referenced only in a comment
    Given a build body contains "// SettingsRoot" as a comment only,
      with no actual AppRoutes.SettingsRoot() construction anywhere
    Then K10.2 still fails for SettingsRoot (comments are trivia, not tokens)

  Scenario: Referenced only in a string literal
    Given a build body contains the string "SettingsRoot" as a literal value,
      with no actual identifier reference
    Then K10.2 still fails for SettingsRoot (string contents are not
      identifier tokens)

  Scenario: Not referenced at all
    Given AppRoutes.UnreachableRoot is declared and no DeepLinkRoute.build
      body anywhere references it
    Then K10.2 fails, naming AppRoutes.swift and `UnreachableRoot`

  Scenario: AppRoutes.swift declares zero members
    Given the AppRoutes enum has no nested AppRoute-conforming types
    Then K10.2 passes trivially (nothing to require)

Feature: K10.3 — pattern segments are well-formed

  Scenario: Valid literal segment
    Given pattern "/settings"
    Then K10.3 passes

  Scenario: Uppercase literal segment
    Given pattern "/Settings"
    Then K10.3 fails, naming the file, the pattern, and segment `Settings`

  Scenario: Underscore literal segment
    Given pattern "/settings/lang_code"
    Then K10.3 fails, naming segment `lang_code`

  Scenario: Valid parameter segment
    Given pattern "/scanner/result/:code"
    Then K10.3 passes

  Scenario: Uppercase parameter segment
    Given pattern "/settings/:Code"
    Then K10.3 fails, naming segment `:Code`

  Scenario: Parameter with no name
    Given pattern "/settings/:"
    Then K10.3 fails, naming segment `:` (empty name after colon)

  Scenario: Empty pattern
    Given pattern ""
    Then K10.3 passes vacuously — DeepLinkPattern.init parses "" to zero
      segments, same as DeepLinkPattern's own documented behaviour, so there
      is nothing to validate

  Scenario: Root pattern "/"
    Given pattern "/"
    Then K10.3 passes vacuously, for the same reason

Feature: K10.4 — the app entry point wires .onOpenURL to deepLinkRouter.open

  Scenario: Both tokens present
    Given App/Sources/iOSDigitalWalletApp.swift contains .onOpenURL and
      calls composition.deepLinkRouter.open(url) inside it
    Then K10.4 passes

  Scenario: .onOpenURL deleted
    Given the .onOpenURL modifier is removed from the entry point
    Then K10.4 fails on the .onOpenURL assertion, naming the file

  Scenario: deepLinkRouter.open renamed
    Given .onOpenURL still calls something, but not named deepLinkRouter.open
    Then K10.4 fails on the deepLinkRouter.open assertion, naming the file

  Scenario: Both present but only in a comment
    Given the entry point has no real .onOpenURL / deepLinkRouter.open call,
      only mentions them in a // comment
    Then K10.4 still passes, because it is a deliberate source-text
      substring check (Decision #2) — this is the rule's documented,
      accepted weak spot, not a bug: it is a regression net for deletion,
      not a semantic check, and Task 9's UI test is the real behavioural
      coverage

Feature: K10.5 — no pattern declares the same parameter name twice

  Scenario: No parameters
    Given pattern "/settings"
    Then K10.5 passes

  Scenario: One parameter
    Given pattern "/scanner/result/:code"
    Then K10.5 passes

  Scenario: Two distinct parameters
    Given pattern "/tx/:from/:to"
    Then K10.5 passes

  Scenario: Two identical parameters
    Given pattern "/tx/:id/:id"
    Then K10.5 fails, naming the file, the pattern, and parameter `:id`

  Scenario: Three parameters, two identical
    Given pattern "/tx/:id/:type/:id"
    Then K10.5 fails once for `:id` (the duplicate set, not per-occurrence)
```

**Self-review — can each rule fail in the "too strict" direction too?**
Yes: K10.2's comment/string-literal scenarios prove the rule does *not* fire
on a merely-textual mention (it would be too strict, and wrong, if it did);
K10.3's empty-pattern/root-pattern scenarios prove the rule does not fire on
patterns that are vacuously valid (K10.3 would be too strict if `""` or `"/"`
were flagged); K10.4's comment-only scenario is the deliberately accepted
counter-example that shows exactly where the crude text-pin can be fooled —
recorded as a known, accepted limitation rather than silently swallowed. All
three were exercised for real, not just reasoned about (see RED evidence
below).

---

