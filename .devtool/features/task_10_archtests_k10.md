---
id: "task_10_archtests_k10"
status: "todo"
priority: "high"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T03:42:16+07:00"
completedAt: null
labels: ["governance", "archtests", "swift-syntax", "ci"]
order: "a10"
---

# Task 10: ArchTests K10 Governance Rules

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

The repo's stated philosophy is *enforce structurally, do not rely on
discipline*. Deep links are declared in many packages, so without a rule they
drift: duplicates shadow each other silently, and a cross-feature route can exist
that only compiled code can reach.

Add rule **K10** to `ArchTests`, using the existing `SyntaxScanner` (swift-syntax
AST, not regex) and honouring `baseline.txt`.

| Rule | Assertion |
|---|---|
| **K10.1** | No two `DeepLinkRoute` declarations across the repo share a pattern string |
| **K10.2** | Every route type declared in `Platform/Navigation/AppRoutes.swift` appears in at least one `DeepLinkRoute.build` body |
| **K10.3** | Pattern segments are well-formed — literal `^[a-z0-9-]+$`, parameter `^:[a-z][a-zA-Z0-9]*$` |

**K10.2 is the strict one, and deliberately so.** A route promoted to
`AppRoutes` is by definition a cross-feature entry point; an entry point that
cannot be addressed by URL is exactly the asymmetry criterion 2.1 exists to
prevent. The escape hatch, if a genuine case appears, is the existing
`ArchTests/baseline.txt` ledger — which is currently empty and must stay empty
when this task completes.

## Relevant Files & Context Pointers

- `ArchTests/Tests/ArchTests/DeepLinkRulesTests.swift` — **new**
- `ArchTests/Sources/ArchTestSupport/SyntaxScanner.swift` — AST scanning helpers to reuse
- `ArchTests/Sources/ArchTestSupport/Baseline.swift` — accepted-violation ledger
- `ArchTests/Sources/ArchTestSupport/RepoRoot.swift` — path resolution
- `ArchTests/baseline.txt` — must remain empty
- `ArchTests/Tests/ArchTests/RouteLocationRulesTests.swift` — **K9**, the closest existing rule to model on
- `Packages/Platform/Sources/Platform/Navigation/AppRoutes.swift` — K10.2's input set
- `Features/*/Sources/*/Presentation/*RouteProvider.swift` — where declarations live

## Design Rationale

- **AST, not regex.** K10 must read `DeepLinkRoute("…")` initialiser arguments
  and the identifiers referenced inside `build` closures. Regex over source would
  produce false positives on comments and string interpolation; `SyntaxScanner`
  already exists precisely to avoid that, and **K9** is the working precedent for
  scanning route declarations.
- **Model K10.2 on K9's structure.** K9 already walks `AppRoutes.swift` for
  declared route types and cross-references feature sources; K10.2 is the same
  traversal with a different target set, so the two should share helpers rather
  than each re-deriving "what is a route declared in `AppRoutes`".
- **Lowercase-kebab literals, camelCase parameters.** URL paths follow web
  convention; parameter names follow the repo's existing camelCase key rule from
  `.agents/rules/LOCALIZATION_RULES.md`. Stating both in one rule keeps patterns
  greppable and predictable.
- **K10.1 makes resolution order irrelevant**, which is what lets
  [Task 5](task_5_deeplink_router_engine.md)'s first-match-wins contract be safe
  in practice.
- Applicable skill in `.agents/skills/`: **`test-driven-development`** — each rule
  is proven by injecting a violation first.

## TDD Checklist

- [ ] **RED**: K10.1 — inject a duplicate pattern into a fixture and observe the
      rule fail, naming both declaration sites.
- [ ] **RED**: K10.2 — add a route to `AppRoutes` with no `DeepLinkRoute`
      referencing it and observe the rule fail, naming the route.
- [ ] **RED**: K10.3 — inject `"/Settings"` (uppercase), `"/settings/:Code"`
      (uppercase parameter) and `"/settings/lang_code"` (underscore) and observe
      each fail.
- [ ] **GREEN**: implement the three rules against the real repository tree; all
      pass with the declarations from
      [Task 7](task_7_feature_deeplink_declarations.md).
- [ ] **REFACTOR**: share the `AppRoutes`-traversal helper with K9 rather than
      duplicating it; keep `ArchTests` lint-clean (its sources are in scope).

## Definition of Done

- [ ] `swift test --package-path ArchTests` passes; K10.1–K10.3 are present and
      each has been observed failing on an injected violation (noted per rule).
- [ ] Failure messages name the offending file and pattern — a rule that fails
      without saying where is not done.
- [ ] `ArchTests/baseline.txt` is still **empty**.
- [ ] `ArchTests` is never linked into the app (unchanged property, re-verified).
- [ ] SwiftLint `--strict` and SwiftFormat `--lint` clean over `ArchTests/`.

## Dependencies & Blockers

- Blocked by [Task 7](task_7_feature_deeplink_declarations.md) — the rules need
  real declarations to pass against.
- Blocks nothing; but [Task 11](task_11_mason_brick_deeplinks.md)'s generated
  output must satisfy K10, so land this first so the brick is validated by it.

## References & Rollback

- Source Spec §7 (Governance — ArchTests K10).
- `docs/architecture/ARCHITECTURE.md` §VI — the K1–K9 governance table K10 joins
  (updated in [Task 14](task_14_deeplink_docs.md)).
- **Rollback**: test-only, and outside the app binary. Deleting
  `DeepLinkRulesTests.swift` removes enforcement without touching product code.
  Prefer baselining a specific violation over deleting the rule.
