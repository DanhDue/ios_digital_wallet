import Combine
import Core
import Foundation
import Platform
import SwiftUI
import XCTest
@testable import iOSDigitalWallet

// MARK: - Combine recorder

/// Sinks a `Never`-failing publisher into an ordered array so tests can assert
/// the exact emission *sequence*. Lock-guarded / `@unchecked Sendable` so the
/// sink needs no actor hop. Subscribe BEFORE the action under test.
final class Recorder<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []
    private var cancellable: AnyCancellable?

    init(_ publisher: some Publisher<Value, Never>) {
        cancellable = publisher.sink { [weak self] value in
            guard let self else { return }
            lock.lock()
            storage.append(value)
            lock.unlock()
        }
    }

    var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var count: Int {
        values.count
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}

// MARK: - Lifecycle-state projection (the shipping enum is not Equatable)

enum LifecycleTag: String, Equatable {
    case foreground
    case background
    case inactive

    init(_ state: AppLifecycleChanged.State) {
        switch state {
        case .foreground: self = .foreground
        case .background: self = .background
        case .inactive: self = .inactive
        }
    }
}

// MARK: - Tab-visibility projection

struct TabVisibility: Equatable {
    let tab: Int
    let visible: Bool

    init(_ event: ShellTabVisibilityChanged) {
        tab = event.tabIndex
        visible = event.isVisible
    }
}

// MARK: - Silent logger

final class SilentLogger: Core.Logger, @unchecked Sendable {
    func debug(_: String, file _: String, function _: String, line _: Int) {}
    func info(_: String, file _: String, function _: String, line _: Int) {}
    func error(_: String, file _: String, function _: String, line _: Int) {}
}

// MARK: - In-memory SecureCacheStore fake

/// A `SecureCacheStore` fake for tests: `Core.KeychainCacheStore(backend:)` is
/// `internal` to `Core`, so `App` cannot construct one directly. Dictionary-
/// backed, `@unchecked Sendable` with an `NSLock`, mirroring the style of
/// `Packages/Core/Tests/CoreTests/TestSupport.swift`'s `InMemoryKeychainBackend`.
final class InMemorySecureCacheStore: SecureCacheStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    func get<T: Codable>(_: T.Type, key: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = storage[key] else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func set(_ value: some Codable, key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = try? JSONEncoder().encode(value)
    }

    func remove(key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}

// MARK: - 401 URLProtocol stub

/// A `URLProtocol` that answers every request with `HTTP 401` and an empty body.
final class Stub401URLProtocol: URLProtocol {
    /// A fallback URL used only if a request somehow carries none.
    private static let fallbackURL = URL(fileURLWithPath: "/stub")

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let url = request.url ?? Self.fallbackURL
        if let response = HTTPURLResponse(
            url: url,
            statusCode: 401,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
        ) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLSession {
    /// An ephemeral session whose only transport is `Stub401URLProtocol`.
    static func stubbed401() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Stub401URLProtocol.self]
        return URLSession(configuration: config)
    }
}

// MARK: - DeepLink test doubles (Task 8)

/// A `RouteProvider` that declares exactly the `DeepLinkRoute`s passed to it —
/// mirrors `Packages/Platform/Tests/PlatformTests/TestSupport.swift`'s
/// `FakeDeepLinkRouteProvider`, restated here because that type belongs to a
/// separate test target (`PlatformTests`) and is not visible from `App`'s.
/// `canHandle`/`destination` are never exercised by `DeepLinkRouter` — it only
/// ever reads `deepLinks` — so both are trivial stubs.
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

/// Configurable `DeepLinkGuard` fake. Records every `evaluate` call so a test
/// can assert an exact invocation count, mirroring `PlatformTests`'s fake of
/// the same name (again restated here — separate test target, not visible
/// from `App`'s).
@MainActor
final class FakeDeepLinkGuard: DeepLinkGuard {
    private(set) var callCount = 0
    var decide: (_ stack: [any AppRoute], _ requiresAuth: Bool) -> GuardDecision

    init(decide: @escaping (_ stack: [any AppRoute], _ requiresAuth: Bool) -> GuardDecision = { _, _ in .allow }) {
        self.decide = decide
    }

    func evaluate(_ stack: [any AppRoute], requiresAuth: Bool) -> GuardDecision {
        callCount += 1
        return decide(stack, requiresAuth)
    }
}

/// Builds a `URL` from `urlString`, failing the current test (rather than
/// crashing on a force-unwrap) if construction fails — mirrors
/// `PlatformTests`'s helper of the same name.
func deepLinkTestURL(_ urlString: String, file: StaticString = #filePath, line: UInt = #line) -> URL {
    guard let url = URL(string: urlString) else {
        XCTFail("test setup: '\(urlString)' must construct a URL", file: file, line: line)
        return URL(fileURLWithPath: "/test-setup-failure")
    }
    return url
}

/// Builds the `NavigationPath` `AppRouter.navigate(to:inTab:)` would produce
/// for `routes`, so a test can assert exact route **identity and payload**
/// with a single `XCTAssertEqual(router.tabPaths[i], expectedDeepLinkPath([...]))`
/// — `NavigationPath` has no public element subscript, but it does conform
/// to `Equatable`, and `AnyAppRoute`'s equality (`AnyHashable(wrapped) ==
/// AnyHashable(wrapped)`) compares both the concrete route type and its
/// stored properties. Mirrors `PlatformTests`'s helper of the same name
/// (restated here — separate test target, not visible from `App`'s).
func expectedDeepLinkPath(_ routes: [any AppRoute]) -> NavigationPath {
    var path = NavigationPath()
    for route in routes {
        path.append(AnyAppRoute(route))
    }
    return path
}

// MARK: - DeepLink flow test support (Task 9)

/// Builds a fresh, fully real `AppComposition` for Tier C use: a fresh
/// `AppEventBus` (never `.shared`, so tests never see each other's events),
/// an in-memory `SecureCacheStore` (never touches the Keychain), and — when
/// given — a test guard injected through `AppComposition`'s existing
/// `deepLinkGuard:` seam (Task 8 delivered it; this does not add a new one).
/// `tabResolver` is left at its production default (`ShellTabResolver`) so
/// tab placement always matches the real shell layout; only the guard is
/// ever swapped. `nil` keeps `AppComposition`'s own production default
/// (`SessionDeepLinkGuard` with an empty redirect list).
@MainActor
func makeComposition(guard deepLinkGuard: (any DeepLinkGuard)? = nil) -> AppComposition {
    AppComposition(
        eventBus: AppEventBus(),
        secureCacheStore: InMemorySecureCacheStore(),
        deepLinkGuard: deepLinkGuard
    )
}
