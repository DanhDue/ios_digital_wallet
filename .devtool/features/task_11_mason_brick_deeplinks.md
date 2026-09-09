---
id: "task_11_mason_brick_deeplinks"
status: "todo"
priority: "medium"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T03:42:16+07:00"
completedAt: null
labels: ["tooling", "mason", "scaffolding"]
order: "a11"
---

# Task 11: Mason ios_mvi_feature Brick — deepLinks Scaffold

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

A governance rule that only existing code satisfies rots the moment someone runs
the generator. `mason make ios_mvi_feature --name Payments` must produce a
feature that satisfies **K10** on the first build, with no manual step.

Teach the brick's `RouteProvider` template to emit a `deepLinks` property:

```swift
public var deepLinks: [DeepLinkRoute] {
    [DeepLinkRoute("/{{name.snakeCase()}}") { _ in [{{name.pascalCase()}}Root()] }]
}
```

Two constraints on the generated pattern:

- It must satisfy **K10.3** — literal segments are `^[a-z0-9-]+$`. Confirm which
  Mason case helper produces that for a multi-word feature name (`snakeCase`
  yields underscores, which K10.3 rejects); use `paramCase`/kebab if that is what
  the brick exposes, and pin the choice with a Tier B scenario using a two-word
  feature name.
- It must satisfy **K10.1** — a newly generated feature must not collide with an
  existing pattern. The feature name is already unique across the repo, so the
  pattern inherits that uniqueness; the Tier B table records it.

The brick's printed checklist gains one line: *"register the provider on
`deepLinkRouter` (automatic inside the marker region) and add a `TabPlacement` in
`ShellTabResolver` if this feature owns a tab."*

`ios_remove_feature` needs no change — it removes the whole package.

## Relevant Files & Context Pointers

- `bricks/ios_mvi_feature/__brick__/Features/{{name.pascalCase()}}/Sources/{{name.pascalCase()}}/Presentation/{{name.pascalCase()}}RouteProvider.swift` — the template to edit
- `bricks/ios_mvi_feature/brick.yaml` — variable declarations
- `bricks/ios_mvi_feature/hooks/` — post-generation hooks and the printed checklist
- `mason.yaml` / `mason-lock.json` — brick registry
- `ArchTests/Tests/ArchTests/DeepLinkRulesTests.swift` — the rules the output must satisfy
- `Features/Scanner/Sources/Scanner/Presentation/ScannerRouteProvider.swift` — the hand-written reference the template should match

## Design Rationale

- **Generate the minimum that passes governance.** One root pattern, no
  parameters, `requiresAuth: false`. A generator that emits speculative child
  routes creates dead code in every new feature.
- **The generated provider must mirror the hand-written one.** Divergence between
  brick output and the reference feature is how templates decay; the Tier B
  scenario diffs the shapes.
- **Verification is by running the generator, not by reading the template.** The
  only meaningful check is: generate a feature, build it, run `ArchTests`, then
  remove it with the inverse brick and confirm a clean tree.
- Applicable skills in `.agents/skills/`: **`verification-before-completion`** —
  this is Tier B work whose evidence is executed commands and pasted output.

## TDD Checklist

**TDD Adaptation:** Mason bricks are code generators, not runtime behaviour —
there is no unit under test to drive RED-first. The repo's Tier B standard
applies instead: a **Verification-Scenario table, executed and pasted**. The
substitution is stated here rather than silently dropping structure.

| # | Scenario | Expected |
|---|---|---|
| 1 | `mason make ios_mvi_feature --name Payments` | `PaymentsRouteProvider` contains `deepLinks` with pattern `/payments` |
| 2 | `mason make ios_mvi_feature --name PaymentHistory` (two words) | pattern satisfies K10.3 — no underscore, no uppercase |
| 3 | `swift test --package-path Features/Payments` | passes with no manual edit |
| 4 | `swift test --package-path ArchTests` | K10.1/K10.2/K10.3 green with the generated feature present |
| 5 | `tuist generate --no-open && xcodebuild build` | app builds with the generated feature wired |
| 6 | `mason make ios_remove_feature --name Payments` then `git status` | tree clean; no orphan marker-region lines |
| 7 | Brick checklist output | contains the new `deepLinkRouter` / `TabPlacement` line |

- [ ] Execute every scenario and paste the real output.
- [ ] Fix the template until all seven pass.

## Definition of Done

- [ ] All seven verification scenarios executed with output pasted into the PR.
- [ ] Generated output is byte-comparable in shape to
      `ScannerRouteProvider.deepLinks` (same ordering, same doc-comment style).
- [ ] No other feature's files are touched by generation or removal (invariant
      **R5**) — proven by `git status` in scenarios 6.
- [ ] `mason-lock.json` updated if the brick version changed.
- [ ] SwiftLint `--strict` clean on the generated feature before any manual edit.

## Dependencies & Blockers

- Blocked by [Task 4](task_4_deeplink_route_provider_seam.md) — the template
  emits `DeepLinkRoute`.
- Blocked by [Task 10](task_10_archtests_k10.md) — scenario 4 is the point of
  this task, and needs K10 to exist.

## References & Rollback

- Source Spec §8 (Mason brick changes).
- `README.md` — "Add a feature"; `bricks/ios_remove_feature` — the inverse.
- **Rollback**: revert the template file and the hook's checklist string. Already
  generated features keep their `deepLinks` property, which remains valid because
  the protocol requirement has a default — no generated code breaks.
