import Core
import Foundation
import XCTest
@testable import Network

// MARK: - URL / response helpers

/// `URL(string:)` is failable and `force_unwrapping` is a lint error even in
/// tests — funnel literal URLs through here.
func requireURL(_ string: String, file: StaticString = #filePath, line: UInt = #line) -> URL {
    guard let url = URL(string: string) else {
        XCTFail("not a valid URL: \(string)", file: file, line: line)
        return URL(fileURLWithPath: "/invalid")
    }
    return url
}

/// `XCTAssertThrowsError` for an `async` operation. Closure form (not an
/// autoclosure) so SwiftFormat's `hoistAwait` cannot strip the inner `await`.
func assertThrowsAsync(
    _ operation: () async throws -> some Any,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    onError: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await operation()
        XCTFail(message.isEmpty ? "expected an error to be thrown" : message, file: file, line: line)
    } catch {
        onError(error)
    }
}

// MARK: - Test models

struct Widget: Codable, Equatable, Sendable {
    let id: Int
    let name: String
}

struct RequiredFieldModel: Codable, Equatable, Sendable {
    let mustExist: String
}

// MARK: - Spy Logger

/// Records every call so tests can assert on level + substring. Lock-guarded /
/// `@unchecked Sendable` per the repo pattern.
final class SpyLogger: Logger, @unchecked Sendable {
    struct Entry: Sendable {
        let level: String
        let message: String
    }

    private let lock = NSLock()
    private var storage: [Entry] = []

    var entries: [Entry] {
        lock.withLock { storage }
    }

    func messages(level: String) -> [String] {
        lock.withLock { storage.filter { $0.level == level }.map(\.message) }
    }

    func debug(_ message: String, file _: String, function _: String, line _: Int) {
        append("debug", message)
    }

    func info(_ message: String, file _: String, function _: String, line _: Int) {
        append("info", message)
    }

    func error(_ message: String, file _: String, function _: String, line _: Int) {
        append("error", message)
    }

    private func append(_ level: String, _ message: String) {
        lock.withLock { storage.append(Entry(level: level, message: message)) }
    }
}

// MARK: - Spy AuthEventSink

/// Records every `onUnauthorized(reason:)` call. `onUnauthorized()` is now an
/// extension overload, so the requirement to implement is the `reason` form.
final class SpyAuthEventSink: AuthEventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [LogoutReason] = []

    /// Reasons passed to `onUnauthorized(reason:)`, in call order.
    var reasons: [LogoutReason] {
        lock.withLock { storage }
    }

    var callCount: Int {
        lock.withLock { storage.count }
    }

    func onUnauthorized(reason: LogoutReason) {
        lock.withLock { storage.append(reason) }
    }
}

// MARK: - Spy TokenRefresher

/// Records every `refresh(refreshToken:)` call (count + the refresh token seen)
/// and returns a scripted `TokenRefreshResult`, optionally after an artificial
/// delay so tests can drive concurrency / cancellation timing. Lock-guarded /
/// `@unchecked Sendable` per the repo pattern.
final class SpyTokenRefresher: TokenRefresher, @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [String] = []
    /// Maps the 1-based call number to the result to return.
    private let results: @Sendable (Int) -> TokenRefreshResult
    private let delay: Duration

    init(delay: Duration = .zero, results: @escaping @Sendable (Int) -> TokenRefreshResult) {
        self.delay = delay
        self.results = results
    }

    /// Convenience for a fixed result on every call.
    convenience init(_ canned: TokenRefreshResult, delay: Duration = .zero) {
        self.init(delay: delay, results: { _ in canned })
    }

    /// Number of `refresh` calls made so far.
    var callCount: Int {
        lock.withLock { seen.count }
    }

    /// The most recent `refreshToken` argument, or `nil` if never called.
    var lastRefreshToken: String? {
        lock.withLock { seen.last }
    }

    func refresh(refreshToken: String) async -> TokenRefreshResult {
        let callNumber = lock.withLock { () -> Int in
            seen.append(refreshToken)
            return seen.count
        }
        if delay != .zero {
            try? await Task.sleep(for: delay)
        }
        return results(callNumber)
    }
}

// MARK: - Test gate

/// A latch for coordinating async test interceptors: closed until `openGate()`.
final class TestGate: @unchecked Sendable {
    private let lock = NSLock()
    private var open = false

    var isOpen: Bool {
        lock.withLock { open }
    }

    func openGate() {
        lock.withLock { open = true }
    }
}

// MARK: - Call recorder + recording interceptor

/// Ordered log of interceptor events shared by several `RecordingInterceptor`s.
final class CallRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var calls: [String] {
        lock.withLock { storage }
    }

    func record(_ entry: String) {
        lock.withLock { storage.append(entry) }
    }
}

/// A `RequestInterceptor` that appends `"<name>.adapt"` / `"<name>.didReceive"`
/// / `"<name>.retry"` to a shared `CallRecorder`, optionally stamps a header so
/// `adapt` ordering is observable on the wire too, and — when given an
/// `onRetry` closure — scripts its `retry` answer (default `.doNotRetry`).
final class RecordingInterceptor: RequestInterceptor, @unchecked Sendable {
    let name: String
    private let recorder: CallRecorder
    private let stampHeader: Bool
    private let onRetry: (@Sendable (URLRequest) async -> RetryDecision)?

    init(
        name: String,
        recorder: CallRecorder,
        stampHeader: Bool = false,
        onRetry: (@Sendable (URLRequest) async -> RetryDecision)? = nil
    ) {
        self.name = name
        self.recorder = recorder
        self.stampHeader = stampHeader
        self.onRetry = onRetry
    }

    func adapt(_ request: URLRequest) async -> URLRequest {
        recorder.record("\(name).adapt")
        guard stampHeader else { return request }
        var mutated = request
        let existing = mutated.value(forHTTPHeaderField: "X-Chain") ?? ""
        mutated.setValue(existing.isEmpty ? name : "\(existing),\(name)", forHTTPHeaderField: "X-Chain")
        return mutated
    }

    func didReceive(_: HTTPURLResponse) {
        recorder.record("\(name).didReceive")
    }

    func retry(_ request: URLRequest, dueTo _: RetryReason) async -> RetryDecision {
        recorder.record("\(name).retry")
        guard let onRetry else { return .doNotRetry }
        return await onRetry(request)
    }
}

// MARK: - Retry-once wrapper

/// Minimal client wrapper: on `NetworkError.unauthorized` it retries the request
/// exactly once. Proves the 401 → `onUnauthorized()` count equals the number of
/// distinct 401 *responses*, not the number of *attempts*.
struct RetryOnceClient: APIClient {
    let wrapped: APIClient

    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        do {
            return try await wrapped.send(request)
        } catch NetworkError.unauthorized {
            return try await wrapped.send(request)
        }
    }
}

// MARK: - Environments

struct FixedEnvironment: Environment {
    let baseURL: URL
    var defaultHeaders: [String: String] = [:]
}
