# BDD Scenarios — Task 2: DeepLink URL Normalisation

Captured from the implementer's QA pass at implementation time (2026-09-10).
Historical record of what was analysed — including partitions deliberately
excluded. The executable form is the XCTest suite; see the task's Relevant
Files. Task: [task_2_deeplink_url_normalisation](../../../features/task_2_deeplink_url_normalisation.md)

## PHASE 1: BDD SCENARIOS

Before writing code I ran a throwaway Swift script (`swift <script>.swift`,
deleted afterward) probing real `URLComponents` behavior on this toolchain
(Swift 6, macOS 14 Foundation) so every scenario assertion is grounded in
verified fact, not assumption.

```gherkin
Feature: DeepLink URL normalisation (Source Spec §4.1)

  # --- Happy paths / host-path asymmetry ---

  Scenario: Custom scheme prepends host as the first segment
    Given the URL "app://settings/language"
    When DeepLink is constructed
    Then path is exactly ["settings", "language"]
    And query is exactly [:]

  Scenario: Universal Link (https) discards the host
    Given the URL "https://example.com/settings/language"
    Then path is exactly ["settings", "language"]

  Scenario: Universal Link (http, not just https) also discards the host
    Given the URL "http://example.com/settings/language"
    Then path is exactly ["settings", "language"]

  # --- Segment-count boundaries ---

  Scenario: Empty path is legal (app://)
    Given the URL "app://"
    Then path is exactly [] and query is exactly [:]

  Scenario: Single-segment path (host only, no path component)
    Given the URL "app://settings"
    Then path is exactly ["settings"]

  Scenario: Many-segment path
    Given the URL "app://a/b/c/d"
    Then path is exactly ["a", "b", "c", "d"]

  Scenario: Very long path (boundary stress)
    Given a URL with 50 generated segments "app://s0/s1/.../s49"
    Then path has exactly 50 elements equal to the generated segment list

  # --- Slash normalisation ---

  Scenario: Trailing slash produces no empty segment
    Given "app://settings/language/" → path ["settings", "language"]

  Scenario: Doubled slash collapses with no empty segment
    Given "app://settings//language" → path ["settings", "language"]

  Scenario: URL with only slashes normalises to an empty path
    Given "app:///" → path []

  Scenario: Scheme-only URL (no authority marker at all)
    Given "app:" → path [] and query [:]

  # --- Query partitions ---

  Scenario: Absent query yields an empty dictionary — "app://settings" → [:]
  Scenario: Empty query marker yields an empty dictionary — "app://settings?" → [:]
  Scenario: Single query parameter — "app://settings?locale=en" → ["locale":"en"]
  Scenario: Multiple distinct query parameters — "app://settings?a=1&b=2" → ["a":"1","b":"2"]
  Scenario: Duplicate query keys — last one wins — "app://settings?a=1&a=2" → ["a":"2"]
  Scenario: Valueless query item maps to empty string — "app://settings?flag" → ["flag":""]
  Scenario: Query key with explicit empty value — "app://settings?a=" → ["a":""]
  Scenario: Percent-encoded query value arrives decoded — "app://settings?a=hello%20world" → ["a":"hello world"]

  # --- Percent-encoding / unicode in path ---

  Scenario: Percent-encoded path segment arrives decoded
    Given "app://settings/%C3%A9" (encodes "é") → path ["settings", "é"]

  Scenario: Raw unicode path segment is preserved
    Given "app://settings/héllo" → path ["settings", "héllo"]

  # SUPERSEDED by controller Ruling 4 during review. Kept, not deleted: that this
  # was analysed, accepted, and then overturned is the whole point of the record.
  # Original scenario (WRONG — no longer the contract):
  #   A percent-encoded slash inside a segment becomes a segment boundary after
  #   decoding. Given "app://settings/lang%2Fuage" → path ["settings", "lang", "uage"]
  # Rejected because RFC 3986 §3.3 makes %2F data inside a segment rather than a
  # delimiter, and because /scanner/result/:code (Task 7) would then silently fail
  # to match a QR payload containing an encoded slash — an undiagnosable no-op.

  Scenario: A percent-encoded slash stays inside its segment
    Given "app://settings/lang%2Fuage" → path ["settings", "lang/uage"]

  Scenario: A Task 7 scanner payload with an encoded slash stays three segments
    Given "app://scanner/result/a%2Fb" → path ["scanner", "result", "a/b"]

  # --- Case partitions ---

  Scenario: Custom-scheme host and path segments stored verbatim, never lowercased
    Given "app://SETTINGS/Language" → path ["SETTINGS", "Language"]

  Scenario: Scheme comparison for the host rule is case-insensitive
    Given "HTTPS://Example.com/Settings/Language"
    → path ["Settings", "Language"] (host discarded despite non-lowercase
      scheme spelling; path segments remain verbatim-cased)

  # --- Malformed / hostile input ---

  Scenario: A string that cannot become a URL yields no DeepLink
    Given "" (fails URL(string:) itself) → nil end-to-end

  Scenario: A string with an unterminated IPv6 host bracket yields no DeepLink
    Given "app://[bad_host/path" (fails URL(string:)) → nil end-to-end

  # --- Equatable / Sendable contract ---

  Scenario: Two DeepLinks from the identical URL string compare equal

  Scenario: Two DeepLinks from different URL strings are not equal, even
    when their normalised path/query happen to match
    Given A from "app://settings/language", B from "app://settings/language/"
    Then A.path == B.path but A != B (equality is field-wise over `url` too)

  Scenario: DeepLink crosses an isolation boundary (Sendable contract)
    Given a DeepLink built on the test's isolation
    When captured into a @Sendable closure inside a detached Task
    Then its stored properties are unchanged and it compiles under Swift 6
    strict concurrency
```

### Self-review against the brief

- Every rule-table row has ≥1 scenario: custom scheme host-prepend ✓,
  https/http host-discard ✓, trailing/doubled slash ✓, verbatim case (two
  scenarios: storage verbatim + case-insensitive scheme match) ✓,
  percent-encoding via `.path`/`queryItems` ✓ (path + query + unicode
  variants), duplicate-key last-wins ✓, valueless→`""` ✓,
  `URLComponents` failure → nil ✓ (see finding below), empty path legal ✓.
- DoD's eleven named scenarios are all present: custom-scheme host-as-segment,
  https host discarded, trailing slash, doubled slash, empty path,
  percent-encoded segment, percent-encoded query value, duplicate query key,
  valueless query item, unicode segment, malformed URL ⇒ nil.

