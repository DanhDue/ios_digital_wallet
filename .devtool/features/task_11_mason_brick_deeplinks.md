---
id: "task_11_mason_brick_deeplinks"
status: "done"
priority: "medium"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-11T11:31:46+07:00"
completedAt: "2026-09-11T11:31:46+07:00"
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
    [DeepLinkRoute("/{{name.paramCase()}}") { _ in [{{name.pascalCase()}}Root()] }]
}
```

Three constraints on the generated pattern:

- **`paramCase()` is mandatory, and the choice is already settled** — do not
  re-derive it. K10.3 requires literal segments to match `^[a-z0-9-]+$`.
  `snakeCase()` yields `payment_history` for a two-word feature, and the
  underscore fails that rule, so a brick emitting it would generate code that
  reddens CI the first time anyone scaffolds a multi-word feature. `paramCase()`
  yields `payment-history` and is **already used elsewhere in this same brick**,
  so no new helper is involved. Pin it with a Tier B scenario using a two-word
  name.
- **K10.6 requires the emitted pattern to be a static string literal.** The
  template's `{{…}}` placeholder is substituted at generation time, so the
  generated file contains a plain literal — that satisfies K10.6. Do not make the
  generated code build its pattern from a constant or an interpolation.
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
| 4 | `swift test --package-path ArchTests` | **all six** K10 rules green with the generated feature present |
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
- [ ] `brick.yaml`'s version bumped if the brick's contract changed. (**Not** `mason-lock.json` — it is gitignored at `.gitignore:22`, so it can never be part of a commit; the earlier wording was unsatisfiable.)
- [ ] SwiftLint `--strict` clean on the generated feature before any manual edit.

## Adjacent brick defects — deliberately OUT of this task's scope

Running the generator for real in [Task 6](task_6_scanner_result_subfeature.md)
surfaced two pre-existing brick defects. Neither is deep-link related, so neither
is fixed here; both are recorded so they are not lost with this epic.

1. **`ios_mvi_subfeature/hooks/post_gen.dart:43-54` writes identical untranslated
   English into both the `en` and `vi` entries** for the auto-added title key, and
   nothing validates against it. Every subfeature generated so far has shipped an
   untranslated Vietnamese string, silently — the catalogue stays valid and the
   build stays green. Affects `ios_mvi_subfeature` only.
2. **Neither `ios_mvi_feature` nor `ios_mvi_subfeature` ships a
   `{{name.pascalCase()}}ViewTests.swift` template**, so generated features and
   subfeatures arrive without a view test while every hand-written feature in the
   repo has one. Task 6 had to add one by hand.

Fixing either is a separate decision: they widen a deep-link epic into brick
maintenance. Raise them with the epic owner rather than absorbing them silently.

## Dependencies & Blockers

- Blocked by [Task 4](task_4_deeplink_route_provider_seam.md) — the template
  emits `DeepLinkRoute`.
- Blocked by [Task 10](task_10_archtests_k10.md) — scenario 4 is the point of
  this task, and needs K10 to exist.

## References & Rollback

- Scenario analysis captured at implementation time: [task-11-mason-brick-deeplinks.md](../epic/ios_deeplink_router/bdd/task-11-mason-brick-deeplinks.md)
- Source Spec §8 (Mason brick changes).
- `README.md` — "Add a feature"; `bricks/ios_remove_feature` — the inverse.
- **Rollback**: revert the template file and the hook's checklist string. Already
  generated features keep their `deepLinks` property, which remains valid because
  the protocol requirement has a default — no generated code breaks.
