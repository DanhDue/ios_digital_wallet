---
id: "task_7_mason_has_network_scaffold"
status: "todo"
priority: "medium"
assignee: null
epic: "ios_networking_module"
dueDate: null
created: "2026-09-04T11:36:40Z"
modified: "2026-09-04T11:36:40Z"
completedAt: null
labels: ["tooling", "mason", "scaffolding"]
order: "a7"
---

# Task 7: Mason — `ios_mvi_feature --has_network` scaffolds `Uri` / `Endpoints` / `NetworkModule`

Epic: [ios_networking_module](../epic/ios_networking_module/ios_networking_module.en.md)

**Testing tier: TDD-adapted.** This is a scaffolding/config change: no new runtime behavior in the template itself, so RED/GREEN/REFACTOR is replaced with concrete generate-and-verify steps.

## Requirement Analysis

Teach the `ios_mvi_feature` brick to emit the decentralised per-feature networking pattern when `has_network == true`. Under `Features/<Name>/Sources/<Name>/Data/Remote/`:

| File | Contents |
|---|---|
| `<Name>Uri.swift` | `enum <Name>Uri { static let resource = "<name>" ; static let byId = "/{id}" }` — feature-owned path constants; **no** global `AppUri` |
| `<Name>Endpoints.swift` | `enum <Name>Endpoints { static func list() -> APIRequest ; static func detail(id: String) -> APIRequest }` — `APIRequest` factories built from `<Name>Uri` |
| `<Name>NetworkModule.swift` | `enum <Name>NetworkModule { static func makeRemoteDataSource(client: any APIClient) -> <Name>RemoteDataSource }` — composition helper; the app injects the shared `APIClient` |

Hook (`post_gen`) changes:
- only when `has_network`; the `Network` dependency line in `Tuist/Package.swift` is already added by the existing `has_network` logic — no new marker regions
- append a checklist line: "implement `<Name>RemoteDataSource` against `<Name>Endpoints`; the app already injects `APIClient`."
- keep the accidental-`Feature`-suffix sanitiser and existing `{{ }}` interpolation working; no `{{ }}` tokens left in generated files
- generated files must pass `swiftlint --strict` and `swiftformat --lint`

## Relevant Files & Context Pointers

- `bricks/ios_mvi_feature/brick.yaml` — read (`has_network` var, line ~17)
- `bricks/ios_mvi_feature/__brick__/**` — **EDIT/NEW** conditional template files under `Data/Remote/`
- `bricks/ios_mvi_feature/hooks/**` (`post_gen.dart` or equivalent) — **EDIT** (checklist line; conditional generation)
- `mason.yaml`, `mason-lock.json` — read
- Existing generated reference: `Features/Settings/Sources/Settings/**` (a `--has_network false` feature) and any prior `--has_network true` output
- `Packages/Network/Sources/Network/APIRequest.swift` — the `APIRequest` initializer the templates target
- Spec §3.4; Flutter `docs/architecture/NETWORKING.md` §4 (decentralised `{Feature}Uri`) + §5 (per-module `NetworkModule`)

## Design Rationale

Directly mirrors Flutter's "each module **must own** its API endpoints" rule and the per-module `NetworkModule` DI pattern, adapted to SPM + constructor injection (no `@module` / `get_it`). Keeping URIs decentralised prevents a "God `AppUri`" in `Network`. **Applicable skill: review `bricks/ios_mvi_feature/` prior art; no domain skill applies.**

## Verification Steps (TDD adaptation — stated explicitly)

RED/GREEN/REFACTOR does not apply (template generation, not app behavior). Instead:

- [ ] Add the conditional `Data/Remote/` templates + hook changes.
- [ ] Run `mason make ios_mvi_feature --name Ledger --has_network true` into a throwaway path (the existing brick test harness / CI job).
- [ ] Assert the three files exist, contain no `{{ }}` tokens, and name the feature `Ledger` (not `LedgerFeature`).
- [ ] `swift build` the generated feature package; `swiftlint --strict --config quality/.swiftlint.yml` and `swiftformat --config quality/.swiftformat . --lint` clean.
- [ ] Run `mason make ios_mvi_feature --name Ledger --has_network false` — assert **no** `Data/Remote/` files are generated.
- [ ] Run `mason make ios_remove_feature --name Ledger` (or the repo's removal brick) — assert a clean reversal, base worktree byte-identical.
- [ ] `git status` clean of stray Dart build artifacts (the brick-hooks `.gitignore` exclusions from prior epic work still cover them).

## Definition of Done (DoD)

- All verification steps above pass; existing brick round-trip tests still pass.
- Lint/format clean from repo root; `ArchTests` green (generated feature imports only infrastructure).
- One commit: `[IOS_SUPER_APP_TEMPLATE] Mason: ios_mvi_feature --has_network scaffolds Uri/Endpoints/NetworkModule`.

## Dependencies & Blockers

- Blocked by [Task 3](task_3_network_retry_hook.md) (generated `<Name>Endpoints` uses the `APIRequest` shape; `authRequirement` is optional so a soft dependency, but implement after Task 3 for a coherent template).
- Blocks [Task 8](task_8_docs_networking_refresh_token.md) (docs describe the generated pattern).

## References & Rollback

- `ios-epic-implementation-context` memory: LachyFS Kanban auto-relocates task files; stage brick commits with explicit paths, never `git add -A`.
- Rollback: revert the commit — the brick returns to its current `--has_network` behavior (dependency line only, no `Data/Remote/` scaffold).
