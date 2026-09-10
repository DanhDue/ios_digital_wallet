# BDD Scenarios — Task 7: Feature Deep-Link Declarations & Standalone Tests

Captured from the implementer's QA pass at implementation time (2026-09-10).
Historical record of what was analysed — including partitions deliberately
excluded. The executable form is the XCTest suite; see the task's Relevant
Files. Task: [task_7_feature_deeplink_declarations](../../../features/task_7_feature_deeplink_declarations.md)

## PHASE 1 — BDD SCENARIOS

```markdown
### BDD SCENARIOS

Feature: Scanner declares its URL contract (ScannerRouteProvider.deepLinks)

  Scenario: /scanner matches and builds the tab root
    Given the Scanner provider's declared deepLinks
    When a DeepLink is built from URL "app://scanner"
    And it is matched against the "/scanner" pattern
    Then match succeeds
    And build(params) returns exactly [AppRoutes.ScannerRoot()]
    And that route's requiresAuth is false

  Scenario: /scanner/result/:code matches and builds a two-element stack in order
    Given the Scanner provider's declared deepLinks
    When a DeepLink is built from URL "app://scanner/result/ABC123"
    And it is matched against the "/scanner/result/:code" pattern
    Then match succeeds, params["code"] == "ABC123"
    And build(params) returns exactly [AppRoutes.ScannerRoot(), ScannerResultRoute(code: "ABC123")] in that order
    And that route's requiresAuth is false

  Scenario Outline: near-miss URLs against /scanner/result/:code do not match any declared pattern
    Given the Scanner provider's declared deepLinks
    When a DeepLink is built from URL "<url>"
    Then no declared pattern matches (every DeepLinkRoute.pattern.match returns nil)
    Examples:
      | url                                       | reason                          |
      | app://scanner/result                      | one segment too few             |
      | app://scanner/result/ABC123/extra          | one segment too many            |
      | app://settings/unknown                     | sibling feature's unknown path  |
      | app://wallet/send                          | a different feature's path      |

  Scenario: literal segment case-insensitivity — /SCANNER still matches
    Given the Scanner provider's declared deepLinks
    When a DeepLink is built from URL "app://SCANNER"
    Then the "/scanner" pattern still matches
    And build(params) returns [AppRoutes.ScannerRoot()]

  Scenario: literal segment case-insensitivity — mixed case /Scanner/Result/:code still matches
    Given the Scanner provider's declared deepLinks
    When a DeepLink is built from URL "app://Scanner/Result/AbC123"
    Then the "/scanner/result/:code" pattern still matches
    And params["code"] == "AbC123" (captured case preserved, not lowercased)

  Scenario Outline: :code payload partitions reach the built route unmodified
    Given the Scanner provider's declared deepLinks
    When a DeepLink is built from a URL whose last percent-encoded segment is "<encoded>"
    And it is matched against "/scanner/result/:code" and built
    Then the built ScannerResultRoute.code exactly equals "<decoded>"
    Examples:
      | encoded                                              | decoded                                | note                       |
      | A                                                     | A                                       | short / single char        |
      | (2000 x's)                                            | (2000 x's)                              | long                       |
      | %E9%98%BF%CE%B2%F0%9F%8E%89                           | 阿β🎉                                   | unicode                    |
      | abc%2Fdef%2Fghi                                       | abc/def/ghi                             | slash stays one segment    |
      | https%3A%2F%2Fexample.com%2Fproduct%3Fid%3D42          | https://example.com/product?id=42       | looks like a URL           |

  Scenario: Scanner declares exactly two routes, in stable order
    Given the Scanner provider's declared deepLinks
    Then deepLinks.count == 2
    And deepLinks[0].pattern is "/scanner"
    And deepLinks[1].pattern is "/scanner/result/:code"
    And re-reading deepLinks twice yields the same order

  Scenario: requiresAuth is false on every Scanner-declared route
    Given the Scanner provider's declared deepLinks
    Then every element's requiresAuth == false

Feature: Settings declares its URL contract (SettingsRouteProvider.deepLinks)

  Scenario: /settings matches and builds the tab root
    Given the Settings provider's declared deepLinks
    When a DeepLink is built from URL "app://settings"
    And it is matched against the "/settings" pattern
    Then match succeeds
    And build(params) returns exactly [AppRoutes.SettingsRoot()]
    And that route's requiresAuth is false

  Scenario: /settings/unknown does not match
    Given the Settings provider's declared deepLinks
    When a DeepLink is built from URL "app://settings/unknown"
    Then no declared pattern matches

  Scenario: a Scanner path does not match any Settings-declared pattern
    Given the Settings provider's declared deepLinks
    When a DeepLink is built from URL "app://scanner"
    Then no declared pattern matches

  Scenario: literal segment case-insensitivity — /SETTINGS still matches
    Given the Settings provider's declared deepLinks
    When a DeepLink is built from URL "app://SETTINGS"
    Then the "/settings" pattern still matches
    And build(params) returns [AppRoutes.SettingsRoot()]

  Scenario: Settings declares exactly one route
    Given the Settings provider's declared deepLinks
    Then deepLinks.count == 1
    And deepLinks[0].pattern is "/settings"
    And its requiresAuth == false

Feature: Cross-feature blindness (structural, verified by reading the diff, not a runtime test)

  Scenario: neither provider file imports the other feature
    Then ScannerRouteProvider.swift has no "import Settings"
    And SettingsRouteProvider.swift has no "import Scanner"

  Scenario: declared pattern strings never collide across features
    Given Scanner's patterns {"/scanner", "/scanner/result/:code"}
    And Settings' patterns {"/settings"}
    Then the two sets are disjoint
```

**Self-review against the Definition of Done** — every item mapped to a scenario:
- `swift test --package-path Features/Scanner` standalone → all Scanner scenarios.
- `swift test --package-path Features/Settings` standalone → all Settings scenarios.
- ArchTests K1/K9 stay green → cross-feature-blindness scenarios (no new shared route type, no cross-import).
- Captured path parameters reach the built route unmodified, including case → mixed-case + payload-partition scenarios.
- SwiftLint/SwiftFormat clean → verified via gate commands, not a scenario.
- Missing-parameter defensive `?? ""` → covered implicitly by the near-miss scenarios (a pattern declaring `:code` never matches a link lacking that segment, so the fallback branch of `?? ""` is provably unreachable from any test, per the brief's own instruction not to build error handling around it).

---

