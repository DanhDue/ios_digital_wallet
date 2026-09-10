# BDD Scenarios — Task 3: DeepLinkPattern & DeepLinkParams Matching

Captured from the implementer's QA pass at implementation time (2026-09-10).
Historical record of what was analysed — including partitions deliberately
excluded. The executable form is the XCTest suite; see the task's Relevant
Files. Task: [task_3_deeplink_pattern_matching](../../../features/task_3_deeplink_pattern_matching.md)

## PHASE 1 — BDD SCENARIOS

### BDD SCENARIOS

```gherkin
Feature: DeepLinkPattern matches a normalised DeepLink and yields DeepLinkParams

  # --- Literal match / parameter capture -----------------------------------

  Scenario: All-literal pattern matches an identical path (DoD: "literal match")
    Given the pattern "/settings"
    And a link normalised from "app://settings" (path ["settings"])
    When the pattern matches the link
    Then it succeeds with an empty params set

  Scenario: Single parameter captures a path segment (DoD: "parameter capture")
    Given the pattern "/tx/:id"
    And a link normalised from "app://tx/123" (path ["tx", "123"])
    When the pattern matches the link
    Then it succeeds with params { id: "123" }

  Scenario: Pattern with only parameters captures every segment, including adjacent ones (DoD: "pattern with only parameters")
    Given the pattern "/:a/:b"
    And a link with path ["foo", "bar"]
    When the pattern matches the link
    Then it succeeds with params { a: "foo", b: "bar" }

  # --- Leading slash / root / empty pattern --------------------------------

  Scenario: Leading slash is optional and stripped (DoD: "leading slash optional")
    Given the pattern "/settings" and the pattern "settings"
    Then both parse to the identical segment list [.literal("settings")]
    And the two DeepLinkPattern values are equal

  Scenario: Root pattern "/" matches an empty path (DoD: "root pattern matches an empty path")
    Given the pattern "/" (zero segments)
    And a link with path [] (e.g. "app://")
    When the pattern matches the link
    Then it succeeds with an empty params set

  Scenario: Empty-string pattern is equivalent to the root pattern (adversarial: empty pattern "")
    Given the pattern "" and the pattern "/"
    Then both parse to zero segments and are equal

  Scenario: Trailing slash on a pattern is stripped like a leading one
    Given the pattern "/settings/"
    Then it parses to [.literal("settings")], not [.literal("settings"), <empty>]

  # --- Segment-count boundaries ---------------------------------------------

  Scenario: Pattern fails when the link has too few segments (DoD: "segment count too few")
    Given the pattern "/settings/language" (2 segments)
    And a link with path ["settings"] (1 segment)
    When the pattern matches the link
    Then it fails (returns nil)

  Scenario: Pattern fails when the link has too many segments (DoD: "segment count too many")
    Given the pattern "/settings" (1 segment)
    And a link with path ["settings", "language"] (2 segments)
    When the pattern matches the link
    Then it fails (returns nil)

  Scenario: Root pattern (0 segments) fails against a non-empty path (1 segment) — 0 vs 1 boundary
    Given the pattern "/"
    And a link with path ["settings"]
    Then match fails

  Scenario: Single-segment pattern (1 segment) fails against an empty path (0 segments) — 1 vs 0 boundary
    Given the pattern "/settings"
    And a link with path []
    Then match fails

  Scenario: Many-segment pattern matches an equal-count link exactly (boundary: "many segments")
    Given the pattern "/a/:b/c/:d/e" (5 segments)
    And a link with path ["a", "2", "c", "4", "e"]
    Then match succeeds with params { b: "2", d: "4" }

  # --- Case partitions -------------------------------------------------------

  Scenario: Literal match is case-insensitive, pattern uppercase (DoD: "case-insensitive literal")
    Given the pattern "/Settings/LANGUAGE"
    And a link with path ["settings", "language"]
    Then match succeeds

  Scenario: Literal match is case-insensitive, link uppercase
    Given the pattern "/settings/language"
    And a link with path ["SETTINGS", "Language"]
    Then match succeeds

  Scenario: Parameter value case is preserved exactly (DoD: "parameter value case preserved")
    Given the pattern "/tx/:id"
    And a link with path ["tx", "AbC123"]
    Then match succeeds with params { id: "AbC123" } — not lowercased

  # --- Path vs. query merge ---------------------------------------------------

  Scenario: Path parameter wins over a query parameter of the same name (DoD: "path parameter beats a query parameter of the same name")
    Given the pattern "/tx/:id"
    And a link with path ["tx", "p1"] and query { id: "q1" }
    Then match succeeds with params { id: "p1" }

  Scenario: A query key with no matching path parameter is still reachable
    Given the pattern "/settings"
    And a link with path ["settings"] and query { locale: "en" }
    Then match succeeds with params { locale: "en" }

  Scenario: Colliding and non-colliding params are both merged, with nothing extra or dropped
    Given the pattern "/tx/:id"
    And a link with path ["tx", "p1"] and query { locale: "en", id: "ignored" }
    Then match succeeds with the full params set exactly { id: "p1", locale: "en" }

  # --- Parameter naming edge cases --------------------------------------------

  Scenario: Two parameters with the same name in one pattern — the later segment's value wins
    Given the pattern "/:id/:id"
    And a link with path ["first", "second"]
    Then match succeeds with params { id: "second" }

  Scenario: A pattern segment that is exactly ":" yields an empty-string parameter name (adversarial, permissive init)
    Given the pattern ":"
    Then it parses to [.parameter("")]
    And matching a one-segment link ["anything"] succeeds with params { "": "anything" }

  # --- Adversarial opaque-segment handling -------------------------------------

  Scenario: A link segment containing "/" from %2F binds whole to one parameter
    Given the pattern "/scanner/result/:code"
    And a link normalised from "app://scanner/result/a%2Fb" (path ["scanner", "result", "a/b"])
    Then match succeeds with params { code: "a/b" } — never re-split

  Scenario: An empty query value is preserved as "", not treated as absent
    Given the pattern "/settings"
    And a link with path ["settings"] and query { a: "" }
    Then match succeeds with params { a: "" }, and params["a"] == "" (not nil)

  Scenario: A parameter value that syntactically looks like a pattern segment is captured verbatim
    Given the pattern "/tx/:id"
    And a link with path ["tx", ":not-a-param"]
    Then match succeeds with params { id: ":not-a-param" } — never reinterpreted

  # --- nil on failure is never a partially-populated result --------------------

  Scenario: A mismatch after a parameter was already captured still returns a clean nil
    Given the pattern "/:a/beta"
    And a link with path ["alpha", "gamma"] (segment 1 would bind a="alpha"; segment 2 "beta" != "gamma")
    When the pattern matches the link
    Then the result is nil — asserted as nil, not merely falsy/empty
```

### Self-review against the brief

| Brief rule | Scenario(s) |
|---|---|
| Leading `/` optional, stripped | "Leading slash is optional and stripped", "Root pattern..." |
| `:` prefix ⇒ parameter, else literal | Implicit in every parameter/literal scenario; explicit in ":" edge case |
| Exact segment count, no wildcards | All "Segment-count boundaries" scenarios |
| Case-insensitive literal / parameter value keeps case | "Case partitions" scenarios |
| Path parameters win over query on collision | "Path vs. query merge" scenarios |
| Root pattern `"/"` ⇒ zero segments ⇒ matches empty path | "Root pattern...", "Empty-string pattern...", "Root pattern (0 segments) fails..." |

All ten DoD-named scenarios are present and explicitly tagged above. Boundary values (0/1/many segments, pattern-longer-than-link, link-longer-than-pattern) are covered. `nil`-never-partial is covered by a dedicated scenario, not just incidentally.

---

