---
id: "task_6_scanner_result_subfeature"
status: "todo"
priority: "medium"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-10T03:42:16+07:00"
completedAt: null
labels: ["feature", "scanner", "mason", "mvi"]
order: "a6"
---

# Task 6: Scanner Result Subfeature via Mason Brick

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

The shipped feature set (`Scanner`, `Settings`) contains **no pushed child
screen** — `Settings`' language picker is a `.sheet`, not a route. Without one
there is nothing to demonstrate the two properties that justify this epic's
design: multi-level stack construction (**D6**) and path parameters.

Add a `Result` subfeature to `Scanner` using the **existing brick**:

```bash
mason make ios_mvi_subfeature --feature Scanner --name Result
```

Then give it a feature-private route carrying the scanned payload:

```swift
public struct ScannerResultRoute: AppRoute {
    public let code: String
    public init(code: String)
}
```

`ScannerRouteProvider.canHandle` / `destination(for:)` learn to resolve it, and
`ScannerResultView` renders the code it was handed.

This route is also the concrete proof of blocker **D3**: before
[Task 1](task_1_any_app_route_erasure.md) it could not be reached at all, because
`ShellView` had no destination for it.

**Scope discipline:** a scanner showing the payload it just scanned is generic
enough to keep the template domain-neutral. No parsing, no validation, no
business rules — the screen displays a string.

## Relevant Files & Context Pointers

- `bricks/ios_mvi_subfeature/` — the generator being exercised
- `Features/Scanner/Sources/Scanner/Presentation/Result/` — **new**, brick output
  (`ResultAction/State/Event/ViewModel/View`)
- `Features/Scanner/Sources/Scanner/Presentation/ScannerRouteProvider.swift` — add `ScannerResultRoute` + resolution
- `Features/Scanner/Sources/Scanner/Resources/Localizable.xcstrings` — new keys, `scanner.result.*`
- `Features/Scanner/Tests/ScannerTests/ScannerRouteProviderTests.swift` — existing suite, extend
- `.agents/rules/LOCALIZATION_RULES.md` — key naming rules the new strings must obey
- `scripts/merge_localizations.py` — regenerates `Translations.generated.swift`

## Design Rationale

- **Use the brick, don't hand-write.** Running `ios_mvi_subfeature` doubles as a
  regression check that the brick still produces compiling, test-covered output —
  a Tier B property the template cares about — and guarantees the new screen
  matches the MVI conventions the rest of the repo follows.
- **Feature-private route, not `AppRoutes`.** No other feature needs to navigate
  here, so ArchTests **K9** requires it stay inside the package. It is promoted
  only if that changes.
- **The route carries its parameter as a stored property.** `AppRoute` is
  `Hashable`; a `String` payload keeps it hashable and lets
  `navigationDestination` distinguish two different scanned codes.
- **Localization**: keys are `scanner.result.<key>` in camelCase per
  `.agents/rules/LOCALIZATION_RULES.md`; strings live in the Scanner package's
  own catalogue, never in `App/Resources`.
- Applicable skills in `.agents/skills/`: **`test-driven-development`**.

## TDD Checklist

- [ ] **RED**: `ScannerRouteProviderTests` — `canHandle(ScannerResultRoute(code:))`
      is `true`; `destination(for:)` returns a non-empty view for it and
      `EmptyView` for an unrelated route; two routes with different codes are not
      equal, two with the same code are.
- [ ] **RED**: `ResultViewModel` tests as produced by the brick — `onAppear`
      transitions to content; the code it was constructed with survives into
      state.
- [ ] **GREEN**: run the brick, add `ScannerResultRoute`, wire resolution, render
      the code in `ScannerResultView`.
- [ ] **REFACTOR**: remove any brick boilerplate the screen does not use; run
      `python3 scripts/merge_localizations.py` and confirm the generated
      accessors compile.

## Definition of Done

- [ ] `swift test --package-path Features/Scanner` passes.
- [ ] `swift test --package-path ArchTests` passes — **K2** (Presentation ⇏ Data),
      **K5** (naming), **K9** (feature-private route not shared) all green.
- [ ] `python3 scripts/merge_localizations.py` runs clean; no string literal is
      hard-coded in the view (`t.scanner.result.*` only).
- [ ] `router.navigate(to: ScannerResultRoute(code: "ABC123"))` renders the result
      screen — proven by a test, and impossible before
      [Task 1](task_1_any_app_route_erasure.md).
- [ ] SwiftLint `--strict` and SwiftFormat `--lint` clean.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_any_app_route_erasure.md) — without erasure the new
  route cannot be rendered from a `NavigationStack`.
- Blocks [Task 7](task_7_feature_deeplink_declarations.md) — the
  `/scanner/result/:code` declaration needs this route to exist.

## References & Rollback

- Source Spec §4.11 (template deep-link map), §1.3 blocker **D6**.
- `README.md` — "Add a feature" section documents the brick invocation.
- `bricks/ios_remove_subfeature` — the exact inverse generator.
- **Rollback**: `mason make ios_remove_subfeature --feature Scanner --name Result`
  removes the brick output; then delete `ScannerResultRoute` and its resolution
  branch. Contained entirely within `Features/Scanner`.
