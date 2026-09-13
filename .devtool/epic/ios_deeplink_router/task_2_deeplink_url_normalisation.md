---
id: "task_2_deeplink_url_normalisation"
status: "done"
priority: "high"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T10:31:16+07:00"
completedAt: "2026-09-10T10:31:16+07:00"
labels: ["platform", "deeplink", "parsing"]
order: "a2"
---

# Task 2: DeepLink URL Normalisation

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

Introduce `DeepLink`, the value type that turns a raw `URL` into something the
router can match against. This is where classic deep-link bugs live, so every
normalisation rule below is a named test scenario.

```swift
public struct DeepLink: Equatable, Sendable {
    public let url: URL
    public let path: [String]          // normalised segments, empties removed
    public let query: [String: String]

    public init?(url: URL)             // nil when the URL cannot be normalised
}
```

**Normalisation rules (Source Spec §4.1):**

| Input shape | Rule |
|---|---|
| Custom scheme — `app://settings/language` | `URLComponents.host` is `"settings"`, path is `/language` ⇒ **host is prepended as the first segment** ⇒ `["settings", "language"]` |
| Universal Link — `https://example.com/settings/language` | scheme is `http`/`https` ⇒ **host is discarded** ⇒ `["settings", "language"]` |
| Trailing / doubled slashes | empty segments removed |
| Case | segments are stored **verbatim**, never lowercased. `DeepLinkPattern` (Task 3) lowercases both sides only when comparing a **literal** segment, so a captured parameter value keeps its original case |
| Percent-encoding | query values arrive decoded via `queryItems`. Path segments are split from `percentEncodedPath` **before** decoding, so an encoded slash (`%2F`) stays inside its segment per RFC 3986 §3.3 instead of creating a boundary |
| Duplicate query keys | **last one wins** — never a trap |
| Query item with no value (`?flag`) | maps to `""` |
| `URLComponents(url:resolvingAgainstBaseURL: false)` fails | `init?` returns `nil` |

An empty normalised path (`app://`) is legal and later matches the pattern `"/"`.

## Relevant Files & Context Pointers

- `Packages/Platform/Sources/Platform/Navigation/DeepLink/DeepLink.swift` — **new**
- `Packages/Platform/Tests/PlatformTests/DeepLinkTests.swift` — **new**
- `Packages/Platform/Package.swift` — no dependency change expected; `Foundation` only
- `Packages/Platform/Tests/PlatformTests/TestSupport.swift` — existing helpers

## Design Rationale

- **`URLComponents`, not manual string splitting.** It handles percent-decoding
  and query parsing correctly, and its failure mode is a clean `nil`.
- **The host/path asymmetry is the whole point.** For a custom scheme the
  authority component carries the first meaningful segment; for an `https`
  Universal Link it carries the domain, which is noise. Collapsing both into one
  `path` array means patterns are written once and work for either surface — the
  property that lets Universal Links be enabled later with no code change.
- **`Sendable`** — all stored properties are value types, and a normalised link
  may be handed across isolation boundaries by a consuming project.
- **No scheme or host validation.** iOS only delivers URLs for schemes and
  associated domains the app registered, so a second check would be redundant and
  would break Universal Links for consumers who enable them.
- Applicable skill in `.agents/skills/`: **`test-driven-development`** — this is a
  pure function with a large boundary-value surface, the ideal RED-first task.

## TDD Checklist

- [ ] **RED**: write `DeepLinkTests` covering all eleven scenarios — custom-scheme
      host-as-segment · https host discarded · trailing slash · doubled slash ·
      empty path (`app://`) · percent-encoded segment · percent-encoded query
      value · duplicate query key (last wins) · valueless query item ⇒ `""` ·
      unicode segment · malformed URL ⇒ `nil`.
- [ ] **GREEN**: implement `DeepLink.init?(url:)` to satisfy them.
- [ ] **REFACTOR**: extract the host-handling branch behind a named private
      helper so the `http`/`https` rule is self-documenting; confirm the doc
      comment states each rule.

## Definition of Done

- [ ] `swift test --package-path Packages/Platform` passes with all eleven
      scenarios present and named after the rule they pin.
- [ ] Equivalence partitions covered: custom scheme vs web scheme; empty vs
      single vs multi-segment path; absent vs empty vs populated query.
- [ ] `DeepLink` is `public`, `Equatable`, `Sendable`, and documented with the
      normalisation table.
- [ ] No new package dependency (`Foundation` only).
- [ ] SwiftLint `--strict` and SwiftFormat `--lint` clean.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_any_app_route_erasure.md) only in sequence, not
  technically — this file compiles independently. Run it after Task 1 so `main`
  never carries erasure-less navigation alongside new deep-link types.
- Blocks [Task 3](task_3_deeplink_pattern_matching.md) and
  [Task 5](task_5_deeplink_router_engine.md).

## References & Rollback

- BDD scenarios captured at implementation time: [task-2-deeplink-url-normalisation.md](../epic/ios_deeplink_router/bdd/task-2-deeplink-url-normalisation.md)
- Source Spec §4.1 (`DeepLink` — the normalised URL), §10 Tier A scenario table.
- Apple: `URLComponents`, `URL` — host/path semantics differ per scheme.
- **Rollback**: additive only. Deleting the two new files restores the previous
  state; nothing else references them until Task 3.
