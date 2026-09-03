# Epic: iOS Super App Template — Chuẩn hoá kiến trúc Native iOS

**Ngày**: 2026-09-02 · **Cập nhật v2**: 2026-09-03
**Trạng thái**: Draft v2 — chờ review
**Epic name**: `ios_super_app_template`

## Changelog v1 → v2 (2026-09-03)

| # | v1 | v2 | Lý do |
|---|---|---|---|
| 1 | Feature/Shell là folder trong app target | **Mỗi Feature + Shell là 1 SPM local package** riêng | Compiler ép ranh giới; G9 sandbox đạt thật |
| 2 | Hand-managed `.pbxproj` | **Tuist** (`Project.swift`/`Workspace.swift`/`Tuist/Package.swift`) | Khai báo project như Gradle; brick auto-wire an toàn |
| 3 | SwiftLint regex + grep là governance chính | **`ArchTests` package (swift-syntax, AST)** + đồ thị SPM; SwiftLint chỉ lo style + layer nhẹ; grep script là lớp phòng thủ phụ | Analog `:konsist-test`, đọc AST không phải regex |
| 4 | 1 shared `NavigationPath` | **Mỗi tab 1 `NavigationStack` + path riêng** (`AppRouter.tabPaths[i]`) | Mirror Android `NestedNavigator` + chuẩn iOS |
| 5 | Sàn iOS 13 (Core) / iOS 16 (nav) — mâu thuẫn | **iOS 16 đồng nhất**, giữ `ObservableObject`/Combine | Bỏ mâu thuẫn |
| 6 | `Shell` phụ thuộc Features | **`Shell` mù feature**; chỉ `App` (composition root) gom Feature và wire vào `AppRouter` | Sát ý đồ Hilt `@IntoSet` của Android |
| 7 | `Platform → Core + Framework` | **`Platform → Core` only** (iOS: `AppRoute` là `Hashable`, `RouteProvider` trả `AnyView`, `AppRouter`/`AppEventBus` là Combine — không dùng type nào của `Framework`) | Platform thành peer của Framework/Network/AppUIKit, đồ thị gọn |
| 8 | `Network → Platform` (cho 401 event) | **`Network → Core` only**; 401 → `UserLoggedOut` qua `AuthEventSink` protocol khai ở `Core`, wire ở composition root | `Network` là leaf thật trên `Core` |
| 9 | 1 brick `ios_mvi_feature` | **4 brick**: `ios_mvi_feature`, `ios_mvi_subfeature`, `ios_remove_feature`, `ios_remove_subfeature` | Parity Android |
| 10 | "Incremental migration", whitelist thu nhỏ, baseline | **Greenfield construction**; cơ chế whitelist giữ nhưng rỗng từ đầu tới cuối | Repo là Hello-World, không phải refactor |
| 11 | README + ARCHITECTURE.md | + `AGENTS.md`, `PROJECT_RULES.md`, `.editorconfig`, `ARCHITECTURE.md` mỏng ở root → `docs/` | Đủ payload template như Android |
| 12 | "TDD Checklist" vài gạch đầu dòng | **§9A Testing & Acceptance Standard** (BDD+TDD 3 tier) bake vào mọi task | Đạt bar dual-persona của `epic-implementation` |
| 13 | `onAction` thuần đồng bộ | §5.5 **pattern async-effect** (`Task`/cancellable lưu + cancel khi có action mới) | Không có nó thì không viết được test race |

## Nguồn tham chiếu

| Tài liệu | Vai trò |
|---|---|
| `.devtool/epic/flutter_super_app_template/2026-08-29-flutter-super-app-template-design.md` | **Kim chỉ nam iOS native** — Combine/`ObservableObject`, SPM-only, SwiftLint/SwiftFormat, `MviViewModel` mapping 1:1 từ Kotlin. (v2 **nâng sàn iOS 13 → 16** — xem Changelog #5.) |
| `.devtool/epic/android_super_app_template/2026-09-02-android-super-app-template-design.md` | **Kim chỉ nam layer & module**. |
| `android_digital_wallet/.worktrees/android_super_app_template/` (đã hoàn tất 16 task) | **Bản mẫu đã build xong** — `infra/{core,framework,network,ui_kit,platform}` là Gradle module, `:shell` module riêng, `:konsist-test` module (rule K1–K9 đọc AST), `:libraries:testutils`, 4 brick, `AGENTS.md`/`PROJECT_RULES.md`/`.editorconfig`. Bản iOS bám bố cục này, đổi: Gradle module → SPM local package; Konsist → `ArchTests` (swift-syntax); Hilt `@IntoSet` → Constructor Injection thủ công ở `App`; DFM → không có (gap đã biết). |
| `bloc_digital_wallet/docs/architecture/ARCHITECTURE.md` | **Nguồn chân lý về layer**: `Presentation → Domain ← Data`, Unidirectional Data Flow, naming `*Action/*State/*Event/*ViewModel/*UseCase/*View/*Repository`. |
| `.agents/skills/epic-implementation/SKILL.md` | **Bar chất lượng thực thi** — Phase 2 Dual-Persona (BDD scenario → TDD test → RED trước → GREEN). Skill viết cho Flutter/Dart; **§9A dưới đây override**: Target = **Swift / XCTest**, bootstrap/verify = `tuist generate` + `xcodebuild` + `swift test`, **không** `melos`. |
| `iOSDigitalWallet` (repo này) | Hiện trạng: Xcode project mới toanh — chỉ `iOSDigitalWalletApp.swift` + `ContentView.swift`. Không layer, không module, không tooling. |

---

## 1. Mục tiêu (Goals)

| # | Mục tiêu | Bám tài liệu |
|---|---|---|
| **G1** | **Clean Architecture + MVI + Feature-First**: `Presentation → Domain ← Data`, Domain thuần Swift (cấm `import UIKit/SwiftUI/Combine`), Unidirectional Data Flow, single entry `dispatch()` → `onAction()`, naming `*Action/*State/*Event/*ViewModel/*UseCase/*View/*Repository`. | ARCHITECTURE.md §I–III |
| **G2** | **5 SPM package hạ tầng** (`Core`, `Framework`, `Network`, `AppUIKit`, `Platform`) + **`Shell` package** + **mỗi Feature là 1 package** (`SettingsFeature`, `ScannerFeature`). Feature chỉ phụ thuộc hạ tầng, **không bao giờ phụ thuộc Feature khác** (compiler ép). | android §4.1 |
| **G3** | **Host là container thuần**: `App` target chỉ `@main` + DI wiring + đăng ký `RouteProvider` + publish lifecycle event. `Shell` package dựng tab layout + per-tab `NavigationStack`, **mù feature**. `HomeStubView` nằm trong `Shell` (không phải Feature). | android G3 |
| **G4** | **Giao tiếp cross-feature tập trung**: `Platform` chứa `AppRouter` + `AppRoutes` + `RouteProvider` + `AppEventBus`. `App` là **nơi duy nhất** gom Feature. | android G4 |
| **G5** | **State isolation**: mỗi Feature giữ `MviViewModel` riêng (từ `Framework`). Constructor Injection thủ công. Type trong `Sources/*/Data/` phải `internal`. | android G5 |
| **G6** | **Governance ép bằng cấu trúc**: (a) đồ thị SPM — Feature không khai dependency thì không import được; (b) `ArchTests` (swift-syntax) kiểm layer/naming/route-location/host-privilege; (c) `check_module_boundaries.sh` phòng thủ phụ; (d) GitHub Actions CI chạy cả bộ. | android G6 |
| **G7** | **Feature mới = 1 lệnh Mason**: `mason make ios_mvi_feature --name X` sinh **package đầy đủ** + tự sửa manifest Tuist trong vùng đánh dấu + `tuist generate`. Không đụng Feature khác. | ARCHITECTURE.md §III.3 |
| **G8** | **Template native iOS**: 5 infra package + Shell + 3 feature (home stub trong Shell / scanner stub package / settings real package). `scripts/rename_project.sh` là cửa vào duy nhất sau clone. | flutter §4 |
| **G9** | **Sandbox development thật**: mỗi package `swift build` / `swift test` độc lập, không cần app target. | android G9 |

## 2. Non-Goals

- **DI framework** (Swinject, Needle, Factory): Constructor Injection thủ công.
- **`@Observable` / Observation framework**: giữ Combine + `ObservableObject`. (Chỉ xét lại nếu sàn nâng ≥ iOS 17.)
- **App Extension** (Widget, Share, Watch): ngoài phạm vi. Kiến trúc sẵn sàng nhưng không làm.
- **Dynamic on-demand loading**: iOS không có cơ chế tương đương DFM Android — template là monolithic app đơn, gap đã biết.
- **CocoaPods**: SPM-only.
- **Đổi business logic digital wallet** trong repo gốc.
- **KMP / Flutter integration**: iOS Native App đơn thuần.
- **Worktree-per-task** khi thực thi: 1 worktree cho cả epic (theo `epic-implementation`).

## 3. Nguyên tắc bao trùm

1. **App build & chạy được ở MỌI ranh giới phase.** Mỗi phase là 1 PR review được.
2. **`ARCHITECTURE.md` Flutter là nguồn chân lý về layer.** Bản iOS chỉ ánh xạ thuật ngữ. Phase 1 viết `docs/architecture/ARCHITECTURE.md` bản iOS, cùng cấu trúc mục lục.
3. **Governance ép bằng cấu trúc, không review thủ công.** Vi phạm = CI đỏ.
4. **`Core` là nền bắt buộc cho mọi package. `Framework` chỉ cho package có UI/state.**
5. **SPM-only, Tuist khai báo project.** Không CocoaPods, không sửa `.pbxproj` tay.
6. **Constructor Injection thủ công** ở mọi tầng.
7. **Min deployment target: iOS 16** — đồng nhất toàn repo. `ObservableObject`/Combine (không `@Observable`).
8. **Mọi task testable phải theo §9A** — BDD scenario → TDD test → RED trước → GREEN.

---

## 4. Kiến trúc đích

### 4.1 Cấu trúc thư mục

```
iOSDigitalWallet/
├── Tuist.swift                          ← Tuist config (pin version qua mise.toml / .tuist-version)
├── Workspace.swift                      ← workspace = App project + tất cả local package
├── Project.swift                        ← App target (thin): @main, DI wiring, entitlements, assets
├── Tuist/
│   ├── Package.swift                    ← khai .package(path:) tới các local package
│   │                                      (vùng đánh dấu // tuist:packages:begin/end cho brick)
│   └── ProjectDescriptionHelpers/
│       └── Module.swift                 ← target factory dùng chung (DRY)
│
├── App/
│   ├── Sources/
│   │   ├── iOSDigitalWalletApp.swift    ← @main
│   │   ├── RootView.swift               ← host ShellView
│   │   └── Composition/
│   │       ├── AppComposition.swift     ← dựng AppRouter + AppEventBus, đăng ký RouteProvider
│   │       │                              (vùng // app:route-providers:begin/end cho brick)
│   │       ├── NetworkComposition.swift ← wire 401 interceptor → AppEventBus.publish(UserLoggedOut())
│   │       └── LifecycleObserver.swift  ← ScenePhase → AppEventBus.publish(AppLifecycleChanged)
│   ├── Resources/  Assets.xcassets · Info.plist
│   └── Tests/AppTests/                  ← integration test (đường đi §4.2 use case / sequence)
│
├── Packages/
│   ├── Core/         Package.swift · Sources/Core/** · Tests/CoreTests/**     (stdlib only)
│   ├── Framework/    depends Core       — MviViewModel, MvvmViewModel, ViewState
│   ├── Network/      depends Core       — APIClient, Interceptor, Environment
│   ├── AppUIKit/     depends Core       — Design System, Components  (KHÔNG depends Framework)
│   ├── Platform/     depends Core       — AppRoute(s), RouteProvider, AppRouter, AppEventBus
│   ├── Shell/        depends Platform, Framework, AppUIKit  (KHÔNG depends Feature)
│   └── Features/
│       ├── SettingsFeature/  depends Platform, Framework, Network, AppUIKit
│       └── ScannerFeature/   depends Platform, Framework, AppUIKit
│
├── ArchTests/                           ← package test kiến trúc — KHÔNG link vào app
│   ├── Package.swift                    ← depends swift-syntax (pin đúng Swift toolchain của Xcode)
│   ├── Sources/ArchTestSupport/
│   │   ├── SyntaxScanner.swift · RepoRoot.swift · Baseline.swift · BoundaryWhitelist.swift
│   └── Tests/ArchTests/
│       ├── LayerRulesTests.swift · NamingRulesTests.swift
│       ├── BoundaryRulesTests.swift · HostRulesTests.swift · RouteLocationRulesTests.swift
│
├── quality/          .swiftlint.yml · .swiftformat
├── scripts/          check_module_boundaries.sh · module_boundary_whitelist.txt · rename_project.sh
├── bricks/           ios_mvi_feature · ios_mvi_subfeature · ios_remove_feature · ios_remove_subfeature
├── docs/architecture/ARCHITECTURE.md    ← viết ở Phase 1
├── ARCHITECTURE.md                      ← mỏng, trỏ docs/architecture/ARCHITECTURE.md
├── AGENTS.md · PROJECT_RULES.md · README.md · .editorconfig · mason.yaml
└── .github/workflows/ci.yml
```

### 4.2 Bản đồ module (1:1 Flutter/Android)

| iOS (SPM package) | Flutter (`packages/`) | Android (`:module`) | Nội dung chính | Phụ thuộc |
|---|---|---|---|---|
| `Core` | `core` | `:infra:core` | `DataState`, `AppError`, `Logger`, `SafeExecution`, `ReplayQueue`, `CacheStore`, `SecureCacheStore`, `SessionManager`, `AuthEventSink`, extensions | — (stdlib) |
| `Framework` | `framework` | `:infra:framework` | `MvvmViewModel`, `MviViewModel`, `ViewState`, async-effect helper | `Core` |
| `Network` | `network` | `:infra:network` | `APIClient`, Interceptor, `Environment`, `NetworkError`, `MockAPIClient` | `Core` |
| `AppUIKit` | `ui_kit` | `:infra:ui_kit` | Design System SwiftUI, Common Components (thuần presentational) | `Core` — **KHÔNG** `Framework` |
| `Platform` | `platform` | `:infra:platform` | `AppRoute`, `AppRoutes`, `RouteProvider`, `AppRouter` (per-tab), `AppEvent`, `AppEventBus` | `Core` |
| `Shell` | `lib/shell/` | `:shell` | `ShellView` (3× `NavigationStack`), `ShellViewModel`, `HomeStubView` | `Platform`, `Framework`, `AppUIKit` |
| `SettingsFeature` | `settings` | `:features:settings` | Feature thật, full MVI + Clean, local-only (`CacheStore`) | `Platform`, `Framework`, `Network`, `AppUIKit` |
| `ScannerFeature` | `scanner` (rỗng) | `:features:scanner` | Feature stub scaffold | `Platform`, `Framework`, `AppUIKit` |
| `ArchTests` | — | `:konsist-test` | Rule kiến trúc swift-syntax — không vào build app | `swift-syntax` |
| `App` target | `lib/` | `:app` | `@main`, composition root, đăng ký `RouteProvider`, lifecycle, 401 wiring | `Shell` + mọi Feature + `Platform` |

### 4.3 Sơ đồ phụ thuộc

Xem `ios_super_app_template.en.md` §4.1 (bản canonical). Tóm tắt 4 tầng, DAG một chiều xuống `Core`:

```
Tầng 1 · Application (Host)         App  →  Shell   (App là nơi DUY NHẤT gom Feature; Shell mù feature)
Tầng 2 · Features (mù nhau)         SettingsFeature · ScannerFeature
Tầng 3 · Shared Infrastructure      Platform · Framework · Network · AppUIKit   (ngang hàng, không cạnh nội bộ)
Tầng 4 · Foundation                 Core
```

**Bất biến (ArchTests + đồ thị SPM ép):** mọi mũi tên đổ về `Core`; không Feature nào trỏ Feature khác; chỉ `App` gom nhiều Feature; `Shell` không import Feature (chỉ qua `AppRouter`/`RouteProvider`); `AppUIKit` không phụ thuộc `Framework`; mỗi tầng chỉ trỏ xuống tầng thấp hơn.

### 4.4 Layer trong 1 Feature package

```
Packages/Features/{Name}Feature/
├── Package.swift          ← name "{Name}Feature", depends Platform/Framework/(Network)/AppUIKit
├── Sources/{Name}Feature/
│   ├── Data/              🔵 internal — RepositoryImpl, DataSource, DTO, Mapper
│   │   ├── Remote/  {Name}APIService.swift, {Name}DTO.swift
│   │   ├── Local/   {Name}LocalDataSource.swift
│   │   ├── Mapper/  {Name}Mapper.swift
│   │   └── Repository/ {Name}RepositoryImpl.swift  (implements Domain/{Name}Repository)
│   ├── Domain/            🟡 public — thuần Swift, KHÔNG import UIKit/SwiftUI/Combine
│   │   ├── Entity/     {Name}Entity.swift (struct, value type)
│   │   ├── Repository/ {Name}Repository.swift (protocol)
│   │   └── UseCase/    {Action}UseCase.swift
│   └── Presentation/      🟢 public — SwiftUI View + MviViewModel
│       ├── {Sub}/  {Sub}Action.swift · {Sub}State.swift · {Sub}Event.swift · {Sub}ViewModel.swift · {Sub}View.swift
│       └── {Name}RouteProvider.swift    ← implements RouteProvider
└── Tests/{Name}FeatureTests/            ← BDD scenario → TDD test (§9A Tier A)
```

**Quy tắc (ArchTests kiểm):**
- `Data/` không có `public`/`open` type (K4).
- `Domain/` không `import SwiftUI/UIKit/Combine` (K3).
- `Presentation/` không import `Data/` (K2).
- Feature không import Feature khác (K1 — đồ thị SPM + double-check grep).
- `AppRoute` type dùng chéo phải khai ở `Platform/AppRoutes` (K9).

---

## 5. Framework package — MviViewModel

### 5.1 Mapping 1:1 với Kotlin

| Kotlin (Coroutines/Flow) | Swift (Combine, iOS 16) |
|---|---|
| `uiState: StateFlow<STATE>` | `@Published private(set) var uiState: STATE` |
| `viewState: StateFlow<ViewState<STATE>>` | `@Published private(set) var viewState: ViewState<STATE>` |
| `event` (Channel, 1 collector) | `PassthroughSubject<EVENT, Never> eventSubject` (convention: 1 subscriber) |
| `sharedEvent` (SharedFlow) | `PassthroughSubject<EVENT, Never> sharedEventSubject` |
| `dispatch(action)` → `onAction()` | `func dispatch(_:)` (final) → `func onAction(_:)` (open) |
| `reduce { copy(...) }` | `func reduce(_ transform: (inout STATE) -> Void)` |
| `viewModelScope.launch { }` + `switchMap` | **§5.5 async-effect helper** (`Task` lưu + cancel khi action mới) |
| `startLoading()` / `handleError()` / `showContent()` | cùng tên, update `viewState` |

### 5.2 MvvmViewModel (base)

```swift
@MainActor
open class MvvmViewModel: ObservableObject {
    public var cancellables = Set<AnyCancellable>()
    open func onClear() { cancellables.removeAll() }
    deinit { cancellables.removeAll() }
}
```

### 5.3 ViewState

```swift
public enum ViewState<STATE> {
    case loading
    case error(Error)
    case content(STATE)
}
```

### 5.4 MviViewModel (generic)

```swift
@MainActor
open class MviViewModel<STATE, ACTION, EVENT>: MvvmViewModel {
    @Published public private(set) var uiState: STATE
    @Published public private(set) var viewState: ViewState<STATE> = .loading

    public let eventSubject = PassthroughSubject<EVENT, Never>()       // 1 consumer convention
    public let sharedEventSubject = PassthroughSubject<EVENT, Never>() // multi consumer

    public init(initialState: STATE) { self.uiState = initialState; super.init() }

    public final func dispatch(_ action: ACTION) { onAction(action) }
    open func onAction(_ action: ACTION) {}
    public func reduce(_ transform: (inout STATE) -> Void) { transform(&uiState) }

    public func startLoading() { viewState = .loading }
    public func handleError(_ error: Error) { viewState = .error(error) }
    public func showContent() { viewState = .content(uiState) }
    public func emit(_ event: EVENT) { eventSubject.send(event) }
    public func emitShared(_ event: EVENT) { sharedEventSubject.send(event) }
}
```

### 5.5 Async-effect pattern (v2 — bắt buộc)

`onAction` có thể kích hoạt việc async (gọi UseCase). Pattern: mỗi "effect key" giữ 1 `Task`; action mới cùng key **hủy Task cũ** trước khi chạy Task mới (tương đương `switchMap` / `viewModelScope` + cancel).

```swift
extension MviViewModel {
    /// Chạy async effect; nếu đã có effect cùng `key` đang chạy thì hủy nó trước.
    public func launch(_ key: AnyHashable = "default",
                       _ operation: @escaping () async -> Void) {
        effectTasks[key]?.cancel()
        effectTasks[key] = Task { [weak self] in
            await operation()
            self?.effectTasks[key] = nil
        }
    }
    public func cancelEffects() { effectTasks.values.forEach { $0.cancel() }; effectTasks.removeAll() }
}
// effectTasks: [AnyHashable: Task<Void, Never>] — lưu trong MviViewModel; onClear() gọi cancelEffects().
```

**Hệ quả test (§9A Tier A, task Framework):** dispatch 3 lần nhanh cùng key → chỉ effect cuối chạy tới `reduce`; sau `onClear()` không còn emission; `effectTasks` rỗng.

---

## 6. Platform package

### 6.1 Navigation — per-tab `NavigationStack` (iOS 16)

```swift
public protocol AppRoute: Hashable {}

public enum AppRoutes {                       // route dùng chéo giữa Feature
    public struct SettingsRoot: AppRoute { public init() {} }
    public struct ScannerRoot: AppRoute { public init() {} }
}

public protocol RouteProvider {
    func canHandle(_ route: any AppRoute) -> Bool
    @ViewBuilder func destination(for route: any AppRoute) -> AnyView
}

@MainActor
public final class AppRouter: ObservableObject {
    @Published public var selectedTab: Int
    @Published public var tabPaths: [NavigationPath]        // 1 path / tab — nested nav theo tab
    private var providers: [any RouteProvider] = []

    public init(tabCount: Int, initialTab: Int) {
        self.selectedTab = initialTab
        self.tabPaths = Array(repeating: NavigationPath(), count: tabCount)
    }
    public func register(_ p: any RouteProvider) { providers.append(p) }
    public func navigate(to route: any AppRoute, inTab tab: Int? = nil) { tabPaths[tab ?? selectedTab].append(route) }
    public func pop(inTab tab: Int? = nil) { let t = tab ?? selectedTab; guard !tabPaths[t].isEmpty else { return }; tabPaths[t].removeLast() }
    public func popToRoot(inTab tab: Int? = nil) { let t = tab ?? selectedTab; tabPaths[t] = NavigationPath() }
    public func switchTab(_ i: Int) { selectedTab = i }
    @ViewBuilder public func destination(for route: any AppRoute) -> some View {
        if let p = providers.first(where: { $0.canHandle(route) }) { p.destination(for: route) } else { EmptyView() }
    }
}
```

`ShellView`: `TabView(selection: $router.selectedTab)` với mỗi tab là `NavigationStack(path: $router.tabPaths[i])` + `.navigationDestination(for:)` → `router.destination(for:)`. Re-tap tab active → `popToRoot(inTab:)`. Deep-link / state restoration: **kiến trúc sẵn sàng, không làm** (gap ghi trong ARCHITECTURE.md).

### 6.2 AppEventBus

```swift
public protocol AppEvent {}

public struct ShellTabVisibilityChanged: AppEvent { public let tabIndex: Int; public let isVisible: Bool }
public struct AppLifecycleChanged: AppEvent { public enum State { case foreground, background, inactive }; public let state: State }
public struct UserLoggedOut: AppEvent { public init() {} }

public final class AppEventBus {
    public static let shared = AppEventBus()          // convenience cho publisher OS-triggered
    private let subject = PassthroughSubject<any AppEvent, Never>()   // replay = 0, fire-and-forget
    public init() {}
    public func publish(_ event: any AppEvent) { subject.send(event) }
    public func on<T: AppEvent>(_ type: T.Type) -> AnyPublisher<T, Never> {
        subject.compactMap { $0 as? T }.eraseToAnyPublisher()
    }
}
```

Instance được inject ở composition root; `.shared` chỉ cho các publisher không nhận được injection (interceptor, lifecycle observer) — mirror Android.

---

## 7. Core package

```swift
public enum DataState<T> { case success(T); case error(AppError); case loading }

public struct AppError: Error, Equatable { public let code: String; public let message: String; public let underlying: String? }

public protocol Logger {
    func debug(_ m: String, file: String, function: String, line: Int)
    func info(_ m: String, file: String, function: String, line: Int)
    func error(_ m: String, file: String, function: String, line: Int)
}

public enum SafeExecution {
    public static func run<T>(logger: Logger? = nil, label: String = "", fallback: T, _ block: () throws -> T) -> T {
        do { return try block() }
        catch { logger?.error("[\(label)] \(error)", file: #file, function: #function, line: #line); return fallback }
    }
}

public actor ReplayQueue<T: Codable> {
    private var items: [T] = []
    public init() {}
    public func enqueue(_ item: T) { items.append(item) }
    public func dequeueAll() -> [T] { defer { items.removeAll() }; return items }
}

public protocol CacheStore {
    func get<T: Codable>(_ type: T.Type, key: String) -> T?
    func set<T: Codable>(_ value: T, key: String)
    func remove(key: String)
    func clearAll()
}
public protocol SecureCacheStore: CacheStore {}   // Keychain-backed impl trong Core

public protocol SessionManaging: AnyObject {
    var accessToken: String? { get }
    func update(accessToken: String?)
    func clear()
}

/// Dependency Inversion cho 401: Network publish qua đây, composition root nối vào AppEventBus.
public protocol AuthEventSink: AnyObject { func onUnauthorized() }
```

---

## 8. Giao tiếp cross-feature

| Kênh | Ở đâu | Hình dạng | Ai gom |
|---|---|---|---|
| **`AppRoutes`** (route registry) | `Platform` | `struct XxxRoot: AppRoute`; `appRouter.navigate(to: AppRoutes.SettingsRoot())` | — |
| **`AppEventBus`** | `Platform` | `PassthroughSubject<any AppEvent, Never>` broadcast, replay 0 | — |
| **`RouteProvider`** protocol | cơ chế ở `Platform`, mỗi Feature implement | `class SettingsRouteProvider: RouteProvider`; `App` gọi `appRouter.register(...)` | `App` (composition root) |
| **Direct composition** | `App` | DI wiring + đăng ký RouteProvider | **chỉ `App`** — `ArchTests` HostRules ép |

- **`Shell` không tham gia** — nó chỉ nhận `AppRouter` (injected) và render `router.destination(for:)`. Tab root cũng resolve qua `RouteProvider` (`AppRoutes.SettingsRoot()` / `ScannerRoot()`).
- Không có kênh request/response giữa 2 Feature. Cần kết quả typed → Dependency Inversion: protocol ở `Core`, Feature kia implement.
- **Lifecycle event tối thiểu**: `ShellTabVisibilityChanged` (Shell publish khi đổi tab), `AppLifecycleChanged` (`LifecycleObserver` trong `App` publish từ `ScenePhase`), `UserLoggedOut` (`Network` 401 → `AuthEventSink` → `App` publish).

---

## 9. Tooling chất lượng

### 9.1 SwiftLint / SwiftFormat (`quality/`)

`quality/.swiftlint.yml` — style rules + **custom_rules nhẹ** (bổ trợ ArchTests, bắt sớm trong Xcode):

```yaml
custom_rules:
  no_ui_in_domain:
    included: ".*/Domain/.*\\.swift"
    regex: "^\\s*import\\s+(UIKit|SwiftUI|Combine)\\b"
    message: "Domain thuần Swift — không import UIKit/SwiftUI/Combine"
    severity: error
  no_public_in_data:
    included: ".*/Data/.*\\.swift"
    regex: "^\\s*(public|open)\\s+(final\\s+)?(class|struct|enum|actor|protocol|func|var|let)"
    message: "Data layer phải internal"
    severity: error
```

`quality/.swiftformat` — indent 4, maxwidth 120, `--importgrouping testable-bottom`, `--self remove`.
`Project.swift` thêm Build Phase chạy SwiftLint trên `App/` + các package.

### 9.2 `ArchTests` (swift-syntax) — governance chính

Package độc lập, `swift test`, **không link vào app**. `swift-syntax` pin đúng Swift toolchain của Xcode dùng. Có `Baseline.swift` (chấp nhận vi phạm cũ, siết dần) + `BoundaryWhitelist.swift` (đọc `scripts/module_boundary_whitelist.txt`).

| Rule | Cơ chế | Baseline/whitelist |
|---|---|---|
| **K1** Feature package ∌ dependency tới Feature package khác | assert trên `Package.swift` của mỗi Feature + đồ thị SPM | `module_boundary_whitelist.txt` (rỗng) |
| **K2** `Presentation` ∌ import `Data`; `Domain` ∌ import `Presentation`/`Data` | swift-syntax quét `ImportDecl` theo path | — |
| **K3** `Domain/**` ∌ `import SwiftUI/UIKit/Combine` | swift-syntax quét import | Baseline |
| **K4** `Data/**` không có decl `public`/`open` | swift-syntax duyệt modifier của top-level decl | Baseline |
| **K5** Naming: `*ViewModel : Mvi/MvvmViewModel`; `*UseCase`; bộ `*Action/*State/*Event`; `*View : View`; `*Repository` (protocol, Domain) / `*RepositoryImpl` (Data); `*RouteProvider : RouteProvider` | swift-syntax kiểm type + inheritance clause | — |
| **K6** Chỉ `App` được phụ thuộc > 1 Feature; `Shell` phụ thuộc 0 Feature | assert trên manifest (`Project.swift` + `Packages/*/Package.swift`) | — |
| **K7** `Core` không import package anh em | manifest + import scan | — |
| **K9** `AppRoute` type dùng bởi > 1 Feature phải khai ở `Platform/AppRoutes` | swift-syntax quét usage xuyên package | — |

Chạy: `swift test --package-path ArchTests`.

### 9.3 `scripts/check_module_boundaries.sh` (phòng thủ phụ)

Grep `import <FeatureModule>` trong `Packages/Features/*/Sources/`. Vi phạm không trong `module_boundary_whitelist.txt` → exit 1. Là lưới thứ 2 sau đồ thị SPM + ArchTests K1, không phải cơ chế chính.

### 9.4 GitHub Actions (`.github/workflows/ci.yml`)

```yaml
name: iOS CI
on: { pull_request: {}, push: { branches: [develop, main] } }
jobs:
  quality:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: brew install swiftlint swiftformat tuist
      - run: swiftlint --strict --config quality/.swiftlint.yml
      - run: swiftformat --config quality/.swiftformat . --lint
      - run: bash scripts/check_module_boundaries.sh
      - run: swift test --package-path ArchTests
  packages:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: for p in Packages/Core Packages/Framework Packages/Network Packages/AppUIKit Packages/Platform Packages/Shell Packages/Features/*; do swift test --package-path "$p" || exit 1; done
  app:
    runs-on: macos-15
    needs: [quality, packages]
    steps:
      - uses: actions/checkout@v4
      - run: brew install tuist
      - run: tuist generate --no-open
      - run: xcodebuild test -workspace iOSDigitalWallet.xcworkspace -scheme iOSDigitalWallet -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' CODE_SIGNING_ALLOWED=NO
```

Tuist version pin qua `mise.toml` / `.tuist-version`; CI cài đúng version đó.

---

## 9A. Testing & Acceptance Standard (BDD + TDD)

**Override `epic-implementation` dispatch:** Target = **Swift / XCTest**. Async = `XCTestExpectation` / `await`. `@MainActor` cho mọi `ObservableObject`. Combine emission thu bằng helper `record()` (sink gom vào mảng). `MockAPIClient` có `artificialDelay`. SwiftUI View: tối thiểu host trong `UIHostingController` không crash (hoặc `ViewInspector` nếu thêm).

### Phân tầng — epic-designer gán cho MỖI task

| Tier | Áp cho | Task file bắt buộc có |
|---|---|---|
| **A — Behavioral** | `Core`, `Framework`, `Network`, `Platform`, `Shell`, `*Feature` | `### BDD Scenarios` (Gherkin) → `### TDD Tests` (1:1 scenario) → chứng minh RED → GREEN |
| **B — Tooling/Script/Config** | SwiftLint/format, boundary script, Tuist setup, 4 Mason brick, `rename_project.sh`, cleanup | `### Verification Scenarios` — bảng `input → exit/output kỳ vọng`; ≥1 ca âm + ≥1 guard false-positive |
| **C — Integration/Acceptance** | rewire app, ArchTests bật rule, acceptance E2E | `### End-to-End Scenarios` (Gherkin) phủ §4.2 Use Cases + đường đi §4.3 Sequence |

### Nhóm scenario bắt buộc cho Tier A (BVA + Equivalence Partitioning)

1. **Happy path** — luồng dữ liệu bình thường.
2. **Biên / phân hoạch** — nil, empty, đúng 1 phần tử, nhiều phần tử, min/max số, Codable méo, payload quá cỡ.
3. **State transition** — mọi cạnh `Action → State` hợp lệ + ≥1 cạnh bị bỏ qua/không hợp lệ.
4. **Async / race** — dispatch cùng action ≥3 lần thật nhanh → **chỉ effect cuối** tới `reduce`; hủy effect in-flight; **không emission sau `onClear()`**.
5. **Failure injection** — network timeout, HTTP 5xx, decode fail, cache read hỏng, Keychain unavailable.
6. **Emission order** — assert **chuỗi** `@Published` / `viewState` (`loading → content`, `loading → error`), không chỉ giá trị cuối.
7. **Resource teardown** — `cancellables` rỗng sau `onClear`; `effectTasks` rỗng; subject không giữ retain cycle (weak-ref check).

### Self-review gate (trước khi viết test)

Đối chiếu danh sách scenario với §4.2 Use Cases và §4.3 Sequence Diagram của epic HLD; ghi rõ scenario nào map vào bước nào. Thiếu bước = bổ sung scenario trước khi qua Phase 2.

### DoD (thay "Coverage ≥ 80%" đơn thuần)

- Mọi BDD scenario có **1 test xanh** tương ứng.
- Coverage ≥ 80% là **sàn**, không phải mục tiêu.
- Tier B: mọi hàng trong bảng Verification Scenarios chạy đúng exit/output.
- Tier C: mọi End-to-End Scenario xanh trên simulator.

---

## 10. Mason bricks (4 brick — parity Android)

| Brick | Sinh ra | Auto-wire | Verify (post_gen) |
|---|---|---|---|
| **`ios_mvi_feature`** `--name X --has_network` | `Packages/Features/XFeature/` (Package.swift + `Sources/XFeature/{Data,Domain,Presentation}` + `XRouteProvider` + `Tests/XFeatureTests/`) | (a) append `.package(path: "../Packages/Features/XFeature")` vào `Tuist/Package.swift` trong `// tuist:packages:begin/end`; (b) append `"XFeature"` vào dependency của App target trong `Project.swift` `// tuist:app-deps:begin/end` | `tuist generate` + `swift build --package-path Packages/Features/XFeature`; in checklist: đăng ký `XRouteProvider` trong `AppComposition` (vùng `// app:route-providers:begin/end`), thêm `AppRoutes.XRoot` nếu dùng chéo |
| **`ios_mvi_subfeature`** `--feature X --name Y` | Thêm `Sources/XFeature/Presentation/Y/{YAction,YState,YEvent,YViewModel,YView}.swift` + test | không (cùng package) | `swift build --package-path Packages/Features/XFeature` |
| **`ios_remove_feature`** `--name X` | — | Gỡ đúng 3 điểm wire của `ios_mvi_feature` (Tuist/Package.swift, Project.swift, nhắc gỡ RouteProvider) + xoá `Packages/Features/XFeature/` | `tuist generate` xanh |
| **`ios_remove_subfeature`** `--feature X --name Y` | — | Xoá thư mục `Presentation/Y/` | `swift build` |

Brick sửa manifest **theo dòng, trong vùng đánh dấu** (an toàn hơn `.pbxproj` nhiều); `tuist generate` validate ngay; `ios_remove_feature` là đường lùi.

## 11. Template 3 Features

| Feature | Loại | Nội dung | Tương đương |
|---|---|---|---|
| **Home** | Stub page trong `Shell` | `HomeStubView.swift` — không phải package | Flutter `lib/shell/tabs/home_stub_page.dart`; Android `HomeStubPage.kt` trong `:shell` |
| **Scanner** | `ScannerFeature` package, stub | Đủ scaffold (Data/Domain/Presentation) + `ScannerRouteProvider`, không logic | Flutter `scanner` rỗng; Android `features/scanner` |
| **Settings** | `SettingsFeature` package, thật | Settings screen thật, local-only (`CacheStore`), full MVI + Clean — mẫu tham khảo | Flutter `settings`; Android `features/settings` |

`Shell` 3 tab: home (stub) / scanner (stub) / settings (thật). Tab mặc định = settings (index cuối) — khớp Flutter/Android.

## 12. Script `rename_project.sh`

Cửa vào duy nhất sau clone: `./scripts/rename_project.sh MyWallet com.mycompany.mywallet`

1. Validate: git tree sạch; 2 arg; không space/ký tự lạ trong tên.
2. Thay string `iOSDigitalWallet` → `MyWallet` trong `Project.swift`, `Workspace.swift`, `Tuist/Package.swift`, `App/**`, `*.md`.
3. Đổi `PRODUCT_BUNDLE_IDENTIFIER` / bundle id trong `Project.swift` + `App/Resources/Info.plist`.
4. `git mv App/` giữ nguyên tên (App target), chỉ đổi tên hiển thị + scheme name trong `Project.swift`.
5. **KHÔNG đổi** tên package hạ tầng (`Core`, `Framework`, `Network`, `AppUIKit`, `Platform`, `Shell`) — "vendor namespace" của template. Feature package giữ tên `{Name}Feature`.
6. `tuist generate` + `xcodebuild build -scheme MyWallet CODE_SIGNING_ALLOWED=NO` verify.

Tuist khiến rename gọn: chủ yếu là string trong manifest + Info.plist, **không phẫu thuật `.pbxproj`** (`.xcodeproj`/`.xcworkspace` là artifact sinh ra, không commit — thêm vào `.gitignore`).

## 13. Giả định · Rủi ro · Phụ thuộc

### Giả định
- Min deployment target **iOS 16** đồng nhất. Xcode ≥ 16, Swift toolchain khớp `swift-syntax` pin trong `ArchTests`.
- `.xcodeproj` / `.xcworkspace` **không commit** — sinh bằng `tuist generate`. Repo chỉ commit manifest.
- Mason CLI, Tuist, SwiftLint, SwiftFormat cài sẵn máy dev (document trong README, pin version).

### Rủi ro
| Rủi ro | Giảm thiểu |
|---|---|
| Team chưa quen Tuist / version drift | Pin qua `mise.toml`/`.tuist-version`; README hướng dẫn; CI cài đúng version; Phase 0 chỉ Tuist + placeholder, kiểm chứng trước khi có package |
| `swift-syntax` nặng, khoá theo toolchain | Pin đúng version Swift của Xcode; cache SwiftPM trong CI; `ArchTests` giữ dependency tối thiểu |
| Brick sửa manifest Tuist | Sửa theo dòng trong vùng `// tuist:*:begin/end`; `tuist generate` validate ngay; `ios_remove_feature` đảo ngược |
| Per-tab `NavigationPath` + deep-link restoration | Template chỉ push/pop per tab; state restoration = "sẵn sàng, không làm" (ghi trong ARCHITECTURE.md) |
| `ArchTests` swift-syntax chậm seed / false-positive | `Baseline.swift` chấp nhận vi phạm cũ, siết dần; job CI riêng |
| Không có DFM tương đương | Non-Goal, gap ghi rõ; template monolithic |
| `epic-implementation` SKILL viết cho Flutter (melos, `.dart_tool`) | §9A + Nguồn tham chiếu override: Target Swift/XCTest, verify bằng `tuist generate`/`xcodebuild`/`swift test` |

### Phụ thuộc
- Không phụ thuộc epic Flutter/Android — độc lập repo. Chỉ *đọc* để tham chiếu.
- Quyền tạo `.github/workflows/` + bật Actions.

---

## 14. Lộ trình (4 phase — greenfield, branch `epic/ios-super-app-template`)

**App build & chạy được ở mọi ranh giới phase.** Whitelist cơ chế giữ nhưng rỗng suốt (greenfield, không có spaghetti để gỡ).

| Phase | Kết quả | Trạng thái app | Đảo ngược |
|---|---|---|---|
| **0 — Toolchain & skeleton** | Tuist (`Project.swift`/`Workspace.swift`/`Tuist/Package.swift`/helpers, pin version), `quality/` config, `ArchTests` skeleton (1 rule trivial xanh), `.github/workflows/ci.yml`, root docs (`AGENTS.md`, `PROJECT_RULES.md`, `README`, `.editorconfig`), `.gitignore` (`*.xcodeproj`, `*.xcworkspace`). | Placeholder screen; CI xanh | Xoá files mới |
| **1 — 5 infra package + ARCHITECTURE.md** | `Core`, `Framework` (+ §5.5 async-effect), `Network`, `AppUIKit`, `Platform` — mỗi cái là SPM package có test, wire vào App qua Tuist. `ArchTests` K2/K3/K4/K5/K7 bật. `docs/architecture/ARCHITECTURE.md` (bản iOS) + `ARCHITECTURE.md` mỏng ở root. | Placeholder import 5 package | Mỗi package 1 PR; revert PR |
| **2 — Shell + Features + navigation** | `Shell` package (3× per-tab `NavigationStack`, `ShellViewModel : MviViewModel`, `HomeStubView`); `SettingsFeature` (thật, full stack, `CacheStore`); `ScannerFeature` (stub). `App` composition root: đăng ký `RouteProvider`, publish lifecycle event, wire 401→bus. `ArchTests` K1/K6/K9 bật. | App 3 tab chạy, tab mặc định = Settings | Whitelist là đòn bẩy; Shell/App là 1 PR |
| **3 — Template-hoá + nghiệm thu** | 4 Mason brick (auto-wire manifest Tuist); `scripts/rename_project.sh`; generic hoá docs/asset; acceptance E2E trên worktree: clone → `rename_project.sh` → `mason make ios_mvi_feature --name Payments` → `tuist generate` → `xcodebuild test` + `swift test` mọi package + `ArchTests` **xanh** + 3 tab chạy trong simulator. | Template đã rename, build & chạy | Template trên worktree riêng; `develop` không đụng tới khi merge chủ ý |

epic-designer chẻ mỗi phase ra `task_N_*.md` (dự kiến ~13–15 task), mỗi task gắn Tier A/B/C theo §9A.

---

## 15. Self-review v2

- **Placeholder**: không còn TBD/TODO.
- **Mâu thuẫn iOS 13/16**: đã bỏ — iOS 16 đồng nhất (Changelog #5). `@Observable` vẫn Non-Goal (giữ mapping 1:1 Kotlin Flow).
- **`Platform → Core` only**: xác nhận — không type nào của `Framework` bị `Platform` dùng. Nếu Phase 1 phát hiện cần (khó xảy ra) → thêm dep, đồ thị vẫn DAG.
- **`Shell` mù feature**: khả thi trên iOS (DI thủ công, không cần classpath-scan như Hilt). `App` là aggregator duy nhất — `ArchTests` HostRules ép.
- **`Network → Core` only**: 401 qua `AuthEventSink` (Core) — `Network` là leaf thật. Không còn chuỗi `Network → Platform → …`.
- **Scope**: đủ lớn → epic. 4 phase, ~13–15 task qua epic-designer.
- **Testing bar**: §9A bake BDD+TDD 3 tier vào mọi task; async-effect §5.5 là tiền đề cho test race ở Framework.
- **`.xcodeproj` không commit**: nhất quán với Tuist; `rename_project.sh` + brick chỉ đụng manifest.
- **Helicopter view**: 8 package (5 infra + Shell + 2 Feature) + `ArchTests` + `App` target — bám đúng bố cục Android đã build (`infra/*` + `:shell` + `:features:*` + `:konsist-test` + `:app`); gap DFM ghi nhận rõ là Non-Goal.
