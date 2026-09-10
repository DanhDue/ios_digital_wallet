---
id: "task_3_deeplink_pattern_matching"
status: "done"
priority: "high"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T10:44:27+07:00"
completedAt: "2026-09-10T10:44:27+07:00"
labels: ["platform", "deeplink", "parsing"]
order: "a3"
---

# Task 3: DeepLinkPattern & DeepLinkParams Matching

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

Add the matcher that decides whether a normalised `DeepLink` satisfies a declared
pattern, and what parameters it yields.

```swift
public struct DeepLinkPattern: Hashable, Sendable {
    public enum Segment: Hashable, Sendable {
        case literal(String)
        case parameter(String)
    }
    public let segments: [Segment]

    public init(_ pattern: String)                       // "/settings", "/tx/:id"
    public func match(_ link: DeepLink) -> DeepLinkParams?
}

public struct DeepLinkParams: Equatable, Sendable {
    public subscript(_ key: String) -> String? { get }
}
```

**Rules (Source Spec §4.2):**

- A leading `/` is optional and stripped.
- A segment starting with `:` is a parameter; everything else is a literal.
- Matching requires an **exact segment count**. No wildcards, no globbing, no
  optional segments — YAGNI; add them when a real link needs one.
- Literal comparison is case-insensitive (both sides lowercased). Parameter
  **values** keep their original case.
- `DeepLinkParams` merges path parameters and query items. **Path parameters win**
  on a name collision.
- The root pattern `"/"` has zero segments and matches a link with an empty path.

## Relevant Files & Context Pointers

- `Packages/Platform/Sources/Platform/Navigation/DeepLink/DeepLinkPattern.swift` — **new**
- `Packages/Platform/Sources/Platform/Navigation/DeepLink/DeepLinkParams.swift` — **new**
- `Packages/Platform/Sources/Platform/Navigation/DeepLink/DeepLink.swift` — input type from [Task 2](task_2_deeplink_url_normalisation.md)
- `Packages/Platform/Tests/PlatformTests/DeepLinkPatternTests.swift` — **new**

## Design Rationale

- **`Hashable` pattern.** ArchTests **K10.1** forbids duplicate patterns, and the
  router's table is keyed for fast lookup; both want a hashable value.
- **Exact segment count, no wildcards.** A prefix or wildcard match makes
  resolution order significant and makes K10.1's uniqueness check meaningless —
  two patterns could be distinct strings yet overlap for real URLs. Exact
  matching keeps "unique pattern" and "unambiguous resolution" the same property.
- **Path parameters beat query parameters.** A path segment is structural and
  authored by the pattern; a query item arrives from outside and must never be
  able to shadow it. Without this rule `/tx/:id?id=evil` is ambiguous.
- **Case-insensitive literals.** URLs arrive from mail clients, QR codes and
  chat apps that cheerfully change case. Parameter values must not be touched —
  they may be identifiers or codes.
- Applicable skill in `.agents/skills/`: **`test-driven-development`** — another
  pure function with a clean boundary-value surface.

## TDD Checklist

- [ ] **RED**: `DeepLinkPatternTests` — literal match · parameter capture ·
      leading slash optional · segment count too few · too many ·
      case-insensitive literal · parameter value case preserved · path parameter
      beats a query parameter of the same name · root pattern `"/"` matches an
      empty path · pattern with only parameters.
- [ ] **GREEN**: implement `DeepLinkPattern.init(_:)`, `match(_:)` and
      `DeepLinkParams`.
- [ ] **REFACTOR**: keep segment parsing in one place so
      [Task 10](task_10_archtests_k10.md)'s K10.3 grammar rule can reference the
      same definition rather than re-deriving it.

## Definition of Done

- [ ] `swift test --package-path Packages/Platform` passes with all ten scenarios.
- [ ] Boundary values covered: zero segments, one segment, many segments; pattern
      longer than link and link longer than pattern.
- [ ] `match` returns `nil` — never a partially-populated params object — on any
      failure.
- [ ] Both types are `public`, `Sendable`, and documented with the rule table.
- [ ] SwiftLint `--strict` and SwiftFormat `--lint` clean.

## Dependencies & Blockers

- Blocked by [Task 2](task_2_deeplink_url_normalisation.md) — `match` takes a
  `DeepLink`.
- Blocks [Task 4](task_4_deeplink_route_provider_seam.md) and
  [Task 5](task_5_deeplink_router_engine.md).

## References & Rollback

- BDD scenarios captured at implementation time: [task-3-deeplink-pattern-matching.md](../epic/ios_deeplink_router/bdd/task-3-deeplink-pattern-matching.md)
- Source Spec §4.2 (`DeepLinkPattern` / `DeepLinkParams`), §10 Tier A table.
- **Rollback**: additive only — delete the three new files. Nothing outside the
  package references them until Task 4.
