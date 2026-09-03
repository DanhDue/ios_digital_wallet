---
id: "task_13_ios_mason_bricks"
status: "todo"
priority: "medium"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: null
labels: ["mason", "tooling", "template"]
order: "a13"
---

# Task 13: 4 Mason bricks with Tuist-manifest auto-wire

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: B (tooling / code-gen).** Verification Scenarios table; generated output must build + pass ArchTests.

## Requirement Analysis

`bricks/` — 4 bricks (parity with Android). Mustache templates; `hooks/post_gen.dart` performs the safe manifest edits + verification. Register all 4 in `mason.yaml`.

**`ios_mvi_feature`** `--name X [--has_network true]`
- Generates `Packages/Features/XFeature/`: `Package.swift` (deps `Platform, Framework, [Network,] AppUIKit`), `Sources/XFeature/{Data,Domain,Presentation}/**` mirroring `SettingsFeature` shape, `XRouteProvider`, `Tests/XFeatureTests/` with a `### BDD Scenarios` stub referencing Source Spec §9A Tier A categories and `// See: SettingsFeature` cross-refs.
- `post_gen`: (a) insert `.package(path: "Packages/Features/XFeature")` inside `Tuist/Package.swift` `// tuist:packages:begin/end`; (b) insert `"XFeature"` in `Project.swift` `// tuist:app-deps:begin/end`; (c) run `tuist generate` and `swift build --package-path Packages/Features/XFeature`; (d) print a checklist: register `XRouteProvider` in `App/Sources/Composition/AppComposition.swift` (`// app:route-providers:begin/end`), add `AppRoutes.XRoot` to `Platform` if the route is cross-feature, run `swift test`.

**`ios_mvi_subfeature`** `--feature X --name Y`
- Adds `Sources/XFeature/Presentation/Y/{YAction,YState,YEvent,YViewModel,YView}.swift` + `Tests/.../YViewModelTests.swift` stub. No manifest edit (same package). `post_gen`: `swift build --package-path Packages/Features/XFeature`.

**`ios_remove_feature`** `--name X`
- Deletes `Packages/Features/XFeature/`; removes the two marker-region lines added by `ios_mvi_feature`; prints a checklist to remove the `XRouteProvider` registration + any `AppRoutes.XRoot`. `post_gen`: `tuist generate`.

**`ios_remove_subfeature`** `--feature X --name Y`
- Deletes `Sources/XFeature/Presentation/Y/` + its test. `post_gen`: `swift build`.

## Relevant Files & Context Pointers

- `bricks/{ios_mvi_feature,ios_mvi_subfeature,ios_remove_feature,ios_remove_subfeature}/` — **NEW** (`brick.yaml`, `__brick__/`, `hooks/post_gen.dart`)
- `mason.yaml` — register the 4 bricks
- `Tuist/Package.swift`, `Project.swift` — the marker regions the hooks edit (created in Task 1)
- `Packages/Features/SettingsFeature/` — the worked example templates are modelled on
- Source Spec §10 (brick table + auto-wire mechanism); Android `bricks/{mvi_feature,mvi_subfeature,remove_feature,remove_subfeature}/` (parity reference)

## Design Rationale

Because Tuist manifests are Swift/text (not a binary `.pbxproj`), the bricks can auto-wire safely — line inserts inside named regions, validated immediately by `tuist generate`. `ios_remove_feature` is the exact inverse, so a wrong `mason make` is one command to undo. Checklists still cover the one thing that needs human judgement: whether a route is cross-feature and where the provider is constructed.

**Applicable skills:** none specific; Mason docs.

## Test Plan (Tier B — Verification Scenarios)

TDD adapted: code-generation tooling. Each row runs on a throwaway git worktree, then reverts.

| # | Scenario | Expected |
|---|---|---|
| 1 | `mason make ios_mvi_feature --name Payments --has_network true` | `Packages/Features/PaymentsFeature/` with all layers; no Mustache tokens left |
| 2 | after #1: `grep "PaymentsFeature" Tuist/Package.swift Project.swift` | one entry in each marker region |
| 3 | after #1: `tuist generate && swift build --package-path Packages/Features/PaymentsFeature` | exit 0 |
| 4 | after #1: `swift test --package-path ArchTests` | K2/K3/K4/K5 green on the generated code (naming + layer correct out of the box) |
| 5 | after #1: `swiftlint --strict` on the generated package | exit 0 |
| 6 | `mason make ios_mvi_feature --name Payments --has_network false` | no `Data/Remote/`, no `Network` in `Package.swift` deps |
| 7 | `mason make ios_mvi_subfeature --feature Payments --name Receipt` | adds `Presentation/Receipt/*`; `swift build` exit 0; no manifest change |
| 8 | `mason make ios_remove_feature --name Payments` then `grep PaymentsFeature Tuist/Package.swift Project.swift` | zero hits; `Packages/Features/PaymentsFeature/` gone; `tuist generate` exit 0 |
| 9 | `ios_remove_feature` run twice | second run is a clean no-op (idempotent), non-zero only with a clear "nothing to remove" — **negative/idempotency guard** |
| 10 | manifest region contains an unrelated manual entry | brick insert/remove touches only its own line — **false-positive guard** |
| 11 | `mason make ios_remove_subfeature --feature Payments --name Receipt` | `Presentation/Receipt/` gone; `swift build` exit 0 |

## Definition of Done

- 4 bricks in `bricks/`, registered in `mason.yaml`.
- `ios_mvi_feature` output: builds, passes ArchTests K2–K5 and SwiftLint with zero edits; auto-wired into both manifests; `tuist generate` green.
- `ios_remove_feature` fully reverses `ios_mvi_feature` (Scenario 8) and is idempotent (Scenario 9).
- sub-feature bricks add/remove within an existing package without manifest changes.
- All 11 Verification Scenarios pass; generated test output removed before commit.

## Dependencies & Blockers

- Blocked by [Task 1](task_1_ios_tuist_bootstrap.md) (marker regions), [Task 11](task_11_ios_settings_feature.md) (worked example), [Task 12](task_12_ios_scanner_and_composition.md) (composition wiring the checklist references).
- Blocks [Task 15](task_15_ios_acceptance_e2e.md).

## References & Rollback

- Source Spec §10. Mason: https://docs.brickhub.dev
- Rollback: delete `bricks/ios_*` and their `mason.yaml` entries. No template source changes.
