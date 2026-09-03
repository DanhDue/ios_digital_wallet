import Combine
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
