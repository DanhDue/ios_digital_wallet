---
id: "task_8_docs_networking_refresh_token"
status: "done"
priority: "medium"
assignee: null
epic: "ios_networking_module"
dueDate: null
created: "2026-09-04T11:36:40Z"
modified: "2026-09-04T16:44:53Z"
completedAt: "2026-09-04T16:44:53Z"
labels: ["documentation", "architecture"]
order: "a8"
---

# Task 8: Docs — `NETWORKING.md` + `REFRESH_TOKEN.md` + `ARCHITECTURE.md` update

Epic: [ios_networking_module](../epic/ios_networking_module/ios_networking_module.en.md)

**Testing tier: TDD-adapted.** Documentation — verification is link/diagram/consistency review against the shipped code, not a test suite.

## Requirement Analysis

Ship the two iOS docs that bring the template to Flutter's level of detail, and update the architecture reference.

1. `docs/architecture/NETWORKING.md` — **NEW**, mirrors Flutter `docs/architecture/NETWORKING.md`
   - Core philosophy: infrastructure (`Network` package) vs implementation (feature packages)
   - The dependency rule: `Network` never imports `Platform` or a feature (ArchTests K7)
   - Architecture diagram (mermaid) adapted to SPM packages
   - Decentralised `<Name>Uri` + `<Name>Endpoints`; per-feature `<Name>NetworkModule` taking the shared `APIClient`
   - Why there is no global `AppUri`
   - Optional `BaseResponseObject<T>` and how a feature opts in
2. `docs/architecture/REFRESH_TOKEN.md` — **NEW**, mirrors Flutter `docs/system-design/refresh_token.md`
   - The four problems + solutions **as built here**: race condition (`RefreshCoordinator` actor single-flight), infinite loop (`RefreshTokenEndpoint` + `X-Auth-Retry` marker), rotation (`SessionManager.update(accessToken:refreshToken:)` → Keychain overwrite), storage (`SecureCacheStore` / Keychain)
   - Strategy table; Mobile vs Backend split
   - The three force-logout cases mapped to `LogoutReason` (`.retryStillUnauthorized`, `.refreshFailed`, `.missingRefreshToken`) + the `.transient` no-logout path
   - Public-endpoint whitelist via `APIRequest(authRequirement: .none)`
   - DIP wiring: `TokenRefresher` in `Core`, adapter in the consumer's auth feature, refresh call through `makeBareAPIClient()` (prominent anti-recursion warning)
   - A copy-pasteable `TokenRefresher` adapter sketch
   - The single-flight sequence diagram (mermaid)
3. `docs/architecture/ARCHITECTURE.md` — **EDIT**
   - update the `Network` row: refresh subsystem, `TokenRefresher` seam, `SessionManager` Keychain persistence
   - the "No Alamofire" line is reaffirmed, not changed
   - if there is a K-rules table note about `Network`, confirm K7 wording still holds

## Relevant Files & Context Pointers

- `docs/architecture/NETWORKING.md` — **NEW**
- `docs/architecture/REFRESH_TOKEN.md` — **NEW**
- `docs/architecture/ARCHITECTURE.md` — **EDIT** (`Network` row ~line 317; networking bullet ~line 449; K7 ~line 598)
- Source docs to mirror: `../bloc_digital_wallet/.worktrees/flutter_super_app_template/docs/architecture/NETWORKING.md` and `docs/system-design/refresh_token.md`
- Shipped code to describe accurately: `Packages/Network/Sources/Network/**` (post Tasks 3–5), `Packages/Core/Sources/Core/Auth/**`, `Session/SessionManager.swift`, `App/Sources/Composition/NetworkComposition.swift`, `bricks/ios_mvi_feature/**`
- Spec §3.5

## Design Rationale

Two docs, same split as Flutter, so an engineer moving between the Flutter and iOS templates finds the same structure. Written **after** the code lands (Tasks 1–7) so every symbol name, header, and diagram matches what shipped. **Applicable skill: `superpowers:writing-skills` is not applicable; follow the existing `docs/architecture/ARCHITECTURE.md` house style (tables, mermaid, `[!WARNING]` callouts).**

## Verification Steps (TDD adaptation — stated explicitly)

- [ ] Every type / method / header name in both docs exists in the shipped code (grep each identifier).
- [ ] Every mermaid block renders (paste into a renderer or run the repo's mermaid lint if present).
- [ ] Every relative link resolves from `docs/architecture/`.
- [ ] `ARCHITECTURE.md` `Network` row and K7 wording are consistent with the new docs and with `ArchTests`.
- [ ] Cross-check the three-logout-case table against `RefreshingAuthInterceptorTests` so doc and tests agree.
- [ ] `swiftformat` / `swiftlint` unaffected (docs only); no code changed.

## Definition of Done (DoD)

- Both new docs present, internally consistent, and accurate to the shipped code.
- `ARCHITECTURE.md` updated; "No Alamofire" retained.
- One commit: `[IOS_SUPER_APP_TEMPLATE] Docs: add NETWORKING.md + REFRESH_TOKEN.md; update ARCHITECTURE.md`.

## Dependencies & Blockers

- Blocked by [Task 6](task_6_app_network_composition_wiring.md) and [Task 7](task_7_mason_has_network_scaffold.md) (docs describe the wired composition and the generated pattern).
- References [Task 4](task_4_network_refresh_machinery.md) and [Task 5](task_5_network_base_response_object.md).

## References & Rollback

- Flutter `docs/architecture/NETWORKING.md`, `docs/system-design/refresh_token.md`.
- Rollback: revert the commit — docs removed, `ARCHITECTURE.md` `Network` row restored. No code impact.
