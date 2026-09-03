---
id: "task_9_ios_rewire_arch_doc"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: null
labels: ["architecture", "docs", "governance"]
order: "a9"
---

# Task 9: Rewire app + ARCHITECTURE.md + enable ArchTests layer rules

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: C (integration).** Closes Phase 1. `### End-to-End Scenarios` (Gherkin) + a documentation review gate. No new runtime behavior of its own.

## Requirement Analysis

1. **Rewire the app target**: `App/Sources/RootView.swift` imports all 5 infra packages (`Core`, `Framework`, `Network`, `AppUIKit`, `Platform`) and shows a placeholder that touches one symbol from each (proves linkage), e.g. an `AppButton` (AppUIKit) that logs via a `Core.Logger`. `Project.swift` app-target deps list all 5 inside `// tuist:app-deps:begin/end`.

2. **Implement the real ArchTests rules** (skeleton from Task 3) and enable them:
   - **K2** — `Presentation/**` files don't `import` a `Data` module symbol; `Domain/**` don't import `Presentation`/`Data`. (No feature packages yet, so this runs but finds nothing — the rule is armed for Phase 2.)
   - **K3** — `Domain/**` has no `import SwiftUI|UIKit|Combine`.
   - **K4** — `Data/**` has no `public`/`open` top-level decl.
   - **K5** — naming: `*ViewModel` inherits `MviViewModel`/`MvvmViewModel`; `*UseCase`; `*Action/*State/*Event` present as a set; `*View: View`; `*Repository` protocol in Domain / `*RepositoryImpl` in Data; `*RouteProvider: RouteProvider`.
   - **K7** — `Packages/Core/Package.swift` declares no sibling package; `Core/Sources` imports none of `Framework|Network|AppUIKit|Platform`.
   - Also assert **`AppUIKit` ∌ `Framework`** (manifest check).
   - `baseline.txt` stays empty (greenfield).

3. **Write `docs/architecture/ARCHITECTURE.md`** (iOS variant, same section structure as Flutter's): layer model (`Presentation → Domain ← Data`), the 8-package + `App` map, the 4-tier dependency graph (reuse the HLD §4.1 mermaid), MVI (`Action/State/Event`, `MviViewModel`, async-effect §5.5), naming conventions, navigation (`AppRouter` per-tab + `RouteProvider`), `AppEventBus`, iOS notes (min iOS 16, `ObservableObject` over `@Observable` and why, SPM + Tuist, `.xcodeproj` not committed, deep-link restoration = ready-not-built). Replace the root `ARCHITECTURE.md` stub with a thin pointer.

## Relevant Files & Context Pointers

- `App/Sources/RootView.swift`, `Project.swift` (`// tuist:app-deps` region) — modify
- `ArchTests/Tests/ArchTests/{LayerRulesTests,NamingRulesTests,HostRulesTests}.swift`, `ArchTests/Sources/ArchTestSupport/*` — implement rules
- `docs/architecture/ARCHITECTURE.md` — **NEW**; `ARCHITECTURE.md` (root) — replace stub with pointer
- Source Spec §9.2 (rule table), §3 (principles), §4; Flutter `docs/architecture/ARCHITECTURE.md` (section-structure mirror); Android `docs/architecture/ARCHITECTURE.md` + root pointer (parity)

## Design Rationale

Writing `ARCHITECTURE.md` at the end of Phase 1 (not epic end) means Phase 2 implementers have an accurate reference and new devs can onboard mid-epic. Enabling K2/K3/K4/K5/K7 now — before any feature exists — means the very first feature package is born under enforcement, not retrofitted.

**Applicable skills:** `elements-of-style:writing-clearly-and-concisely` for the doc, if available.

### End-to-End Scenarios

```gherkin
Scenario: the app links all five infra packages
  Given Project.swift lists Core, Framework, Network, AppUIKit, Platform in the app-deps region
  When tuist generate && xcodebuild build ... CODE_SIGNING_ALLOWED=NO
  Then the build succeeds and RootView references one symbol from each package

Scenario: every infra package test suite still passes
  When swift test is run for each of Packages/{Core,Framework,Network,AppUIKit,Platform}
  Then all are green

Scenario: ArchTests layer rules are armed and green on the current tree
  When swift test --package-path ArchTests
  Then K3, K4, K5, K7 and the AppUIKit-not-Framework check all pass with an empty baseline

Scenario: K7 catches a violation
  Given a temporary import of Platform added to a Packages/Core source file
  When swift test --package-path ArchTests
  Then K7 fails naming that file; revert restores green

Scenario: K3 catches a violation
  Given a temporary "import SwiftUI" in a file under a Domain/ path fixture
  Then K3 fails; revert restores green

Scenario: ARCHITECTURE.md review
  Given a developer unfamiliar with the repo reads docs/architecture/ARCHITECTURE.md
  Then they can state the layer rule, the 8 packages, and how to add a Feature
  And the doc has no TBD/TODO and the root ARCHITECTURE.md points to it
```

### Adaptation note

TDD is adapted: this is an integration + documentation task. The "tests" are the ArchTests rules (which do follow RED→GREEN inside `ArchTests`) plus the E2E scenarios above.

## Definition of Done

- `tuist generate && xcodebuild build` + `xcodebuild test` green with all 5 packages linked.
- `swift test --package-path ArchTests` green; K3/K4/K5/K7 + AppUIKit check proven to fire on injected violations (Scenarios 4–5) and pass clean otherwise.
- `docs/architecture/ARCHITECTURE.md` written, reviewed (Scenario 6), committed; root `ARCHITECTURE.md` is a pointer.
- CI green on `develop`.

## Dependencies & Blockers

- Blocked by [Task 5](task_5_ios_framework_package.md), [Task 6](task_6_ios_network_package.md), [Task 7](task_7_ios_appuikit_package.md), [Task 8](task_8_ios_platform_package.md).
- Blocks [Task 10](task_10_ios_shell.md) (Phase 2 starts here).

## References & Rollback

- Source Spec §9.2, §3, §4.
- Rollback: revert `RootView.swift` + `Project.swift` deps + the ArchTests rule files. `ARCHITECTURE.md` can stay (harmless doc).
