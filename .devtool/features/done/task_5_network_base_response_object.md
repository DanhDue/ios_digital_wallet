---
id: "task_5_network_base_response_object"
status: "done"
priority: "medium"
assignee: null
epic: "ios_networking_module"
dueDate: null
created: "2026-09-04T11:36:40Z"
modified: "2026-09-04T16:05:49Z"
completedAt: "2026-09-04T16:05:49Z"
labels: ["network", "feature"]
order: "a5"
---

# Task 5: Network — optional `BaseResponseObject<T>`

Epic: [ios_networking_module](../epic/ios_networking_module/ios_networking_module.en.md)

**Testing tier: A (behavioral).** Small, self-contained.

## Requirement Analysis

Flutter parses a standard API envelope via `BaseResponseObject<T>`. iOS decodes `T` directly. Ship the envelope as an **optional utility** — a feature that wants it decodes `send() as BaseResponseObject<Foo>` and reads `.data`. `send()` is **not** changed; the template imposes no backend response shape.

New: `Packages/Network/Sources/Network/Response/BaseResponseObject.swift`

```swift
public struct BaseResponseObject<T: Decodable & Sendable>: Decodable, Sendable {
    public let data: T?
    public let message: String?
    public let status: Int?
}
```

## Relevant Files & Context Pointers

- `Packages/Network/Sources/Network/Response/BaseResponseObject.swift` — **NEW**
- `Packages/Network/Tests/NetworkTests/BaseResponseObjectTests.swift` — **NEW**
- `Packages/Network/Sources/Network/APIClient.swift` — read only (confirm `send<T: Decodable>` already accepts `BaseResponseObject<Foo>` with no change)
- Spec §3.2 "`Network/Response/BaseResponseObject.swift` (NEW — optional utility)", §1 Non-Goals

## Design Rationale

Mirrors Flutter's `BaseResponseObject<T>` name and role but stays opt-in, so the template does not force a `data`/`message`/`status` contract onto every backend. Being a plain `Decodable` value type, it composes with the existing generic `send`. **Applicable skill: `superpowers:test-driven-development`.**

## TDD Checklist

- [ ] **RED**: `BaseResponseObjectTests` —
  - decodes `{"data":{"id":1},"message":"ok","status":200}` into `BaseResponseObject<Item>` with all fields populated
  - decodes `{"data":{"id":1}}` (no `message` / `status`) → those are `nil`, `data` populated
  - decodes `{"message":"nope","status":404}` → `data == nil`
  - a `URLSessionAPIClient.send()` returning `BaseResponseObject<Item>` over a stubbed body works end-to-end (no `send` change needed)
- [ ] **GREEN**: add the struct.
- [ ] **REFACTOR**: doc-comment stating it is optional and not wired into `send()`.

## Definition of Done (DoD)

- `swift test --package-path Packages/Network` green; all pre-existing tests pass.
- Lint/format clean from repo root; `ArchTests` green.
- One commit: `[IOS_SUPER_APP_TEMPLATE] Network: add optional BaseResponseObject<T> envelope`.

## Dependencies & Blockers

- Not blocked (independent additive file). May be implemented any time after the epic starts.
- Blocks nothing; [Task 8](task_8_docs_networking_refresh_token.md) documents it.

## References & Rollback

- Flutter `docs/architecture/NETWORKING.md` §3 ("Base Models: `BaseResponseObject<T>`").
- Rollback: delete the file + test; nothing depends on it.
