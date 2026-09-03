---
id: "task_3_ios_mason_brick_scaffold"
status: "backlog"
priority: "medium"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["mason", "tooling", "foundation"]
order: "a3"
---

# Task 3: Mason brick scaffold `ios_mvi_feature`

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Create the `bricks/ios_mvi_feature/` Mason brick — the iOS equivalent of `pac_mvi_feature` (Flutter) and `mvi_feature` (Android). This task covers only the **scaffold** (templates + `brick.yaml`); the `post_gen.dart` checklist generator is completed in Task 13.

The brick generates a Feature module with the full 3-layer structure:

```
Features/{Name}/
├── Data/
│   ├── Remote/{Name}APIService.swift
│   ├── Local/{Name}LocalDataSource.swift
│   ├── Mapper/{Name}Mapper.swift
│   └── Repository/{Name}RepositoryImpl.swift
├── Domain/
│   ├── Entity/{Name}Entity.swift
│   ├── Repository/{Name}Repository.swift  ← protocol
│   └── UseCase/Get{Name}UseCase.swift
└── Presentation/
    ├── {Name}Action.swift
    ├── {Name}State.swift
    ├── {Name}Event.swift
    ├── {Name}ViewModel.swift
    ├── {Name}View.swift
    └── {Name}RouteProvider.swift
```

Variables:
- `name` (string, PascalCase): Feature name, e.g. `Payments`
- `has_network` (bool, default true): if false, omit `Data/Remote/` and `Get{Name}UseCase` network call

Templates use Mustache (`{{name.pascalCase()}}`, `{{name.camelCase()}}`) from Mason.

## Relevant Files & Context Pointers

- `bricks/ios_mvi_feature/brick.yaml` — **NEW**
- `bricks/ios_mvi_feature/__brick__/` — **NEW** (Mustache templates)
- `mason.yaml` at repo root — add brick registration if not present
- Reference: `bricks/pac_mvi_feature/` in `bloc_digital_wallet` (Flutter — template structure to mirror)
- Reference: source spec §10 (brick definition)
- Source spec §4.4 (layer structure each template file must implement)

## Design Rationale

`post_gen.dart` deliberately does NOT auto-mutate `.pbxproj` (see source spec §14 risks). Instead, Task 13 will add a `post_gen.dart` that prints a checklist. This split keeps Task 3 simple and low-risk: pure file generation that can be verified without Xcode.

The brick does NOT wire the `RouteProvider` automatically — that requires Xcode project manipulation. The generated `{Name}RouteProvider.swift` has a clear `// TODO: register in iOSDigitalWalletApp.swift` comment as the handoff point.

TDD adaptation: brick template generation — no runtime behavior to unit test. Verification is running `mason make` and inspecting output files.

## TDD Checklist

TDD adapted — code generation tooling task.

- [ ] **WRITE**: `brick.yaml` with `name` and `has_network` vars.
- [ ] **WRITE**: all `__brick__/` template files with correct Mustache substitution.
- [ ] **VERIFY**: `mason make ios_mvi_feature --name Payments --has_network true` → generates `Features/Payments/` with all 10 files; no Mustache tokens remaining in output.
- [ ] **VERIFY**: `mason make ios_mvi_feature --name Scanner --has_network false` → generates without `Remote/` folder and without network UseCase boilerplate.
- [ ] **VERIFY**: generated `PaymentsViewModel.swift` contains `class PaymentsViewModel: MviViewModel<PaymentsState, PaymentsAction, PaymentsEvent>`.
- [ ] **VERIFY**: generated `PaymentsDomain/PaymentsRepository.swift` has no `import SwiftUI/UIKit/Combine` (SwiftLint rule would catch violation).
- [ ] **CLEANUP**: remove generated test output from repo before committing.

## Definition of Done

- `bricks/ios_mvi_feature/` exists with `brick.yaml` + all `__brick__/` templates.
- `mason make ios_mvi_feature --name X` generates correct scaffold for both `has_network=true` and `has_network=false`.
- Generated files pass SwiftLint (run against generated output before cleaning up).
- `mason.yaml` updated to register the brick.

## Dependencies & Blockers

- Not blocked by Tasks 1 or 2 (can run in parallel).
- Blocks [Task 13](task_13_ios_mason_brick_complete.md) (`post_gen.dart` builds on top of this scaffold).

## References & Rollback

- Source spec §10 (Mason brick definition).
- Mason docs: https://pub.dev/packages/mason_cli
- Rollback: delete `bricks/ios_mvi_feature/`. No other files changed.
