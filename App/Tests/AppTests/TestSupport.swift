import Combine
import Core
import Foundation
import Platform
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

// MARK: - 401 URLProtocol stub

/// A `URLProtocol` that answers every request with `HTTP 401` and an empty body.
final class Stub401URLProtocol: URLProtocol {
    /// A fallback URL used only if a request somehow carries none.
    private static let fallbackURL = URL(fileURLWithPath: "/stub")

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
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
