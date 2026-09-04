import Foundation
@testable import Core

// MARK: - Spy Logger

/// Records every call so tests can assert *which* level fired, *how often*, and
/// with *what* message.
final class SpyLogger: Logger, @unchecked Sendable {
    struct Entry: Equatable {
        let level: String
        let message: String
    }

    private let lock = NSLock()
    private var storage: [Entry] = []

    var entries: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var errorEntries: [Entry] {
        entries.filter { $0.level == "error" }
    }

    func debug(_ message: String, file _: String, function _: String, line _: Int) {
        record("debug", message)
    }

    func info(_ message: String, file _: String, function _: String, line _: Int) {
        record("info", message)
    }

    func error(_ message: String, file _: String, function _: String, line _: Int) {
        record("error", message)
    }

    private func record(_ level: String, _ message: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(Entry(level: level, message: message))
    }
}

// MARK: - In-memory Keychain backend

/// A `KeychainBackend` that never touches the real Keychain, so
/// `KeychainCacheStore` behaviour is deterministic in headless CI.
final class InMemoryKeychainBackend: KeychainBackend {
    private(set) var storage: [String: Data] = [:]

    func read(key: String) -> Data? {
        storage[key]
    }

    func write(_ data: Data, key: String) {
        storage[key] = data
    }

    func delete(key: String) {
        storage.removeValue(forKey: key)
    }

    func deleteAll() {
        storage.removeAll()
    }
}

// MARK: - Auth event sink spy

/// Records every `LogoutReason` the system under test reports, in order, so a
/// test can assert both the count and the exact reasons.
final class SpyAuthEventSink: AuthEventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [LogoutReason] = []

    var reasons: [LogoutReason] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func onUnauthorized(reason: LogoutReason) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(reason)
    }
}

// MARK: - TokenRefresher stub

/// A `TokenRefresher` that returns a canned result and counts how many times it
/// was asked to refresh.
final class StubTokenRefresher: TokenRefresher, @unchecked Sendable {
    private let result: TokenRefreshResult
    private let lock = NSLock()
    private var calls = 0

    init(result: TokenRefreshResult) {
        self.result = result
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func refresh(refreshToken _: String) async -> TokenRefreshResult {
        recordCall()
        return result
    }

    private func recordCall() {
        lock.lock()
        defer { lock.unlock() }
        calls += 1
    }
}

// MARK: - Codable fixtures

/// A nested `Codable` value for round-trip tests.
struct Profile: Codable, Equatable {
    struct Address: Codable, Equatable {
        let street: String
        let zip: Int
    }

    let name: String
    let age: Int
    let address: Address
    let tags: [String]
}

/// A `Codable` whose `encode(to:)` always throws — the failure-injection fixture
/// for `set`.
struct EncodeExplodes: Codable, Equatable {
    let marker: Int

    init(marker: Int = 1) {
        self.marker = marker
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        marker = try container.decode(Int.self)
    }

    func encode(to _: Encoder) throws {
        throw AppError(code: "encode.boom", message: "encode always throws")
    }
}

/// A reference type used to assert *identity* (not just equality) of a
/// `SafeExecution` fallback.
final class Box {
    let value: Int
    init(value: Int) {
        self.value = value
    }
}

// MARK: - DataState inspection helpers (test-only, keeps Core's API minimal)

extension DataState {
    var successValue: T? {
        if case let .success(value) = self {
            return value
        }
        return nil
    }

    var errorValue: AppError? {
        if case let .error(appError) = self {
            return appError
        }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}
