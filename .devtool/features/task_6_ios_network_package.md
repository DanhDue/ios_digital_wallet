---
id: "task_6_ios_network_package"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["architecture", "spm", "network"]
order: "a6"
---

# Task 6: Create `Network` SPM local package

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Create `Sources/Network/` — the iOS equivalent of Flutter `packages/network` and Android `:network`. Depends only on `Core`. Features that need API calls import `Network`; features that don't should not be forced to pull networking overhead.

**Contents**:

```
Sources/Network/Sources/Network/
├── APIClient.swift          ← protocol + URLSession implementation
├── APIRequest.swift         ← typed request builder (Endpoint + HTTPMethod)
├── APIResponse.swift        ← generic decoded response wrapper
├── Environment/
│   ├── Environment.swift    ← protocol (baseURL, headers)
│   └── AppEnvironment.swift ← enum (debug/staging/production)
├── Interceptor/
│   ├── RequestInterceptor.swift  ← protocol
│   ├── AuthTokenInterceptor.swift← adds Authorization header
│   └── LoggingInterceptor.swift  ← logs request/response via Core.Logger
├── Error/
│   ├── NetworkError.swift   ← maps HTTP status to AppError
│   └── HTTPStatusCode.swift ← enum of relevant codes
└── Mocks/
    └── MockAPIClient.swift  ← test double implementing APIClient protocol
```

No Alamofire by default — URLSession is sufficient and avoids a third-party SPM dependency in the foundation layer. If a Feature needs Alamofire, it adds it to its own target (not the shared `Network` package).

`401` interceptor publishes `UserLoggedOut` event via `AppEventBus.shared` — closing the lifecycle event loop described in spec §8.

## Relevant Files & Context Pointers

- `Sources/Network/Package.swift` — **NEW** (depends on `Core`)
- `Sources/Network/Sources/Network/` — all files above
- `Sources/Network/Tests/NetworkTests/` — unit tests with `MockAPIClient`
- `iOSDigitalWallet.xcodeproj` — add `Network` local package reference
- Reference: `bloc_digital_wallet/packages/network/lib/` (Flutter — structural mirror)
- Reference: Android `:network` content in spec §4.1

## Design Rationale

`APIClient` is a protocol (not a concrete class) so Features get a testable `MockAPIClient` without importing `URLSession` in tests. The `AuthTokenInterceptor` reads the token from `Core.SessionManager` via constructor injection — no singleton access in interceptor code itself.

The `401 → UserLoggedOut` event publish is the iOS analog of Android's interceptor publishing to `AppEventBus`. It's placed in `Network` (not `Platform`) because the interceptor lives here — `Network` imports `Platform` for the bus. **Note**: this creates a `Network → Platform → Framework → Core` chain, which is acceptable since `Network` is a leaf infra package (nothing else depends on it except Features).

## TDD Checklist

- [ ] **RED**: `APIClientTests` — `MockAPIClient` returns configured response; `NetworkError` maps 401 to `AppError`; `HTTPStatusCode` enum covers common codes.
- [ ] **RED**: `AuthTokenInterceptorTests` — injects `Authorization: Bearer <token>` header when `SessionManager` has a token; skips header when no token.
- [ ] **RED**: `LoggingInterceptorTests` — `Logger.info` called with request URL; `Logger.error` called on 4xx/5xx.
- [ ] **GREEN**: Implement `APIClient`, interceptors, `Environment`, `NetworkError`.
- [ ] **REFACTOR**: Ensure `Domain/` in any Feature does NOT import `Network` directly — only `Data/` layer may. SwiftLint rule enforces this.

## Definition of Done

- `Sources/Network/` builds. Unit tests green. App imports `Network` without error.
- `MockAPIClient` usable in Feature unit tests.
- `401` interceptor publishes `UserLoggedOut` event (integration tested via `AppEventBus`).
- SwiftLint + SwiftFormat clean. Coverage ≥ 70%.

## Dependencies & Blockers

- Blocked by [Task 4](task_4_ios_core_package.md) (depends on `Core`).
- Blocked by [Task 8](task_8_ios_platform_package.md) — **circular risk**: `Network` needs `AppEventBus` from `Platform`; `Platform` needs `Framework`; `Framework` needs `Core`. Resolution: `Network` depends on `Platform` (which depends on `Framework` → `Core`). No cycle.
- Blocks [Task 12](task_12_ios_features_and_routing.md) (`Settings` Feature imports `Network`).

## References & Rollback

- Source spec §4.2 (module map), §8 (UserLoggedOut lifecycle event).
- Rollback: remove `Sources/Network/` + package reference from project.
