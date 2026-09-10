import Combine
import Core
import Foundation
import SwiftUI
import XCTest
@testable import Platform

// MARK: - Combine recorder

/// Thread-safe sink store for exact-sequence assertions on a publisher.
final class Recorder<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []

    var values: [Value] {
        lock.withLock { storage }
    }

    var count: Int {
        lock.withLock { storage.count }
    }

    func append(_ value: Value) {
        lock.withLock { storage.append(value) }
    }
}

extension Publisher where Failure == Never {
    /// Record every value this publisher emits into `recorder`. Keep the
    /// returned `AnyCancellable` alive for as long as recording should continue.
    func record(into recorder: Recorder<Output>) -> AnyCancellable {
        sink { recorder.append($0) }
    }
}

// MARK: - Route test doubles

struct RouteA: AppRoute {}
struct RouteB: AppRoute {}

/// A distinct route type carrying a payload, used by the rapid-navigate test.
struct NumberedRoute: AppRoute {
    let value: Int
}

/// Same shape as `NumberedRoute` (one stored `Int`) but a **distinct type**.
/// Used to prove `AnyAppRoute` equality does not collapse two different route
/// types that happen to carry an identical stored value.
struct AltNumberedRoute: AppRoute {
    let value: Int
}

/// A `RouteProvider` that handles exactly one concrete route type and records
/// each `destination(for:)` call.
final class MockRouteProvider<Handled: AppRoute>: RouteProvider {
    private(set) var destinationCallCount = 0
    private(set) var lastRoute: (any AppRoute)?
    private let builtView: AnyView

    init(view: AnyView = AnyView(Color.clear)) {
        builtView = view
    }

    func canHandle(_ route: any AppRoute) -> Bool {
        route is Handled
    }

    func destination(for route: any AppRoute) -> AnyView {
        destinationCallCount += 1
        lastRoute = route
        return builtView
    }
}

// MARK: - Retain tracking

/// Reference type used to observe whether a subscriber closure outlives its
/// `AnyCancellable`.
final class RetainProbe {
    private(set) var touchCount = 0

    func touch() {
        touchCount += 1
    }
}

// MARK: - DeepLinkRouter test doubles (Task 5)

/// Configurable `DeepLinkGuard` fake. Records every `evaluate` call, in
/// order, so a redirect-re-entrancy test can assert a *bounded* invocation
/// count rather than merely "did not hang". A single instance can play every
/// gating equivalence partition (allow-all, deny-all, redirect-once,
/// always-redirect) by supplying `decide`.
@MainActor
final class FakeDeepLinkGuard: DeepLinkGuard {
    struct Invocation: Equatable {
        let stack: [ObjectIdentifier]
        let requiresAuth: Bool

        /// Compares by each route's dynamic type only — `any AppRoute`
        /// values are not directly `Equatable` across an existential array,
        /// and every test scenario here only needs "which route types, in
        /// which order, with which `requiresAuth`", never full value
        /// equality.
        init(stack: [any AppRoute], requiresAuth: Bool) {
            self.stack = stack.map { ObjectIdentifier(type(of: $0 as Any)) }
            self.requiresAuth = requiresAuth
        }
    }

    private(set) var invocations: [Invocation] = []
    var decide: (_ stack: [any AppRoute], _ requiresAuth: Bool) -> GuardDecision

    init(decide: @escaping (_ stack: [any AppRoute], _ requiresAuth: Bool) -> GuardDecision = { _, _ in .allow }) {
        self.decide = decide
    }

    var callCount: Int {
        invocations.count
    }

    func evaluate(_ stack: [any AppRoute], requiresAuth: Bool) -> GuardDecision {
        invocations.append(Invocation(stack: stack, requiresAuth: requiresAuth))
        return decide(stack, requiresAuth)
    }
}

/// Configurable `TabResolver` fake. Records every `placement(for:)` call.
///
/// `Platform.TabPlacement` is spelled out fully throughout this type: this
/// file also `import SwiftUI`, which declares its own iOS 18+
/// `SwiftUI.TabPlacement`. Both names are visible to unqualified lookup
/// regardless of the `.iOS(.v16)` deployment floor — availability does not
/// hide a declaration from name lookup, only from use — so a bare
/// `TabPlacement` is a genuine compile-time ambiguity here, not just a style
/// choice. Anything that both `import SwiftUI` and references this
/// `Platform` type must qualify it the same way (a note for Task 8's
/// `ShellTabResolver`, which will face the identical collision).
@MainActor
final class FakeTabResolver: TabResolver {
    private(set) var invokedRouteTypes: [ObjectIdentifier] = []
    var decide: (_ route: any AppRoute) -> Platform.TabPlacement?

    init(decide: @escaping (_ route: any AppRoute) -> Platform.TabPlacement? = { _ in nil }) {
        self.decide = decide
    }

    var callCount: Int {
        invokedRouteTypes.count
    }

    func placement(for route: any AppRoute) -> Platform.TabPlacement? {
        invokedRouteTypes.append(ObjectIdentifier(type(of: route as Any)))
        return decide(route)
    }
}

/// Records every call made through `Core.Logger`, so a test can assert a
/// failure path logged exactly once without caring about the exact wording.
/// `@unchecked Sendable` for the same reason as `Recorder` above: the sole
/// mutable state is guarded by `lock`.
final class FakeLogger: Core.Logger, @unchecked Sendable {
    enum Level {
        case debug, info, error
    }

    struct Entry {
        let level: Level
        let message: String
    }

    private let lock = NSLock()
    private var storage: [Entry] = []

    var entries: [Entry] {
        lock.withLock { storage }
    }

    var errorCount: Int {
        entries.filter { $0.level == .error }.count
    }

    func debug(_ message: String, file _: String, function _: String, line _: Int) {
        record(.debug, message)
    }

    func info(_ message: String, file _: String, function _: String, line _: Int) {
        record(.info, message)
    }

    func error(_ message: String, file _: String, function _: String, line _: Int) {
        record(.error, message)
    }

    private func record(_ level: Level, _ message: String) {
        lock.withLock { storage.append(Entry(level: level, message: message)) }
    }
}

/// A `RouteProvider` that declares exactly the `DeepLinkRoute`s passed to
/// it, so `DeepLinkRouterTests` can build a resolution table without a
/// bespoke provider type per scenario. `canHandle`/`destination` are never
/// exercised by `DeepLinkRouter` (it only ever reads `deepLinks`), so both
/// are trivial stubs.
///
/// No class-level `@MainActor` here, mirroring `MockRouteProvider` above:
/// `RouteProvider` itself is not actor-isolated — only its `deepLinks`
/// requirement is `@MainActor` — so isolating the whole type would make
/// `canHandle`/`destination` unable to satisfy their nonisolated
/// requirements.
final class FakeDeepLinkRouteProvider: RouteProvider {
    private let routes: [DeepLinkRoute]

    init(_ routes: [DeepLinkRoute]) {
        self.routes = routes
    }

    func canHandle(_: any AppRoute) -> Bool {
        false
    }

    func destination(for _: any AppRoute) -> AnyView {
        AnyView(EmptyView())
    }

    @MainActor
    var deepLinks: [DeepLinkRoute] {
        routes
    }
}

/// Builds a `URL` from `urlString`, failing the current test (rather than
/// crashing on a force-unwrap) if construction fails. Shared across every
/// `DeepLinkRouterTests*` file so each one doesn't restate it.
func deepLinkTestURL(_ urlString: String, file: StaticString = #filePath, line: UInt = #line) -> URL {
    guard let url = URL(string: urlString) else {
        XCTFail("test setup: '\(urlString)' must construct a URL", file: file, line: line)
        return URL(fileURLWithPath: "/test-setup-failure")
    }
    return url
}

/// Builds an "expected pushed sequence" `NavigationPath` the same way
/// `AppRouterTests` does: `NavigationPath.==` compares type-erased elements,
/// so this is enough to observe both the *types* and the *order*
/// `DeepLinkRouter` actually pushed, without any getter into `NavigationPath`
/// itself. Shared across every `DeepLinkRouterTests*` file.
func expectedDeepLinkPath(_ routes: [any AppRoute]) -> NavigationPath {
    var path = NavigationPath()
    for route in routes {
        path.append(AnyAppRoute(route))
    }
    return path
}

// MARK: - Cache test double

final class InMemoryCacheStore: CacheStore {
    private var storage: [String: Any] = [:]

    func get<T: Codable>(_: T.Type, key: String) -> T? {
        storage[key] as? T
    }

    func set(_ value: some Codable, key: String) {
        storage[key] = value
    }

    func remove(key: String) {
        storage.removeValue(forKey: key)
    }

    func clearAll() {
        storage.removeAll()
    }
}
