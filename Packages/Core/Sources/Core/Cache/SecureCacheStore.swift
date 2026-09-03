import Foundation

/// A `CacheStore` whose backing store is the platform secure enclave (Keychain).
/// Same contract as `CacheStore`; the marker protocol lets callers require
/// secure storage at the type level.
public protocol SecureCacheStore: CacheStore {}

/// Keychain-backed `SecureCacheStore`. JSON-encodes values into generic-password
/// items scoped to `service`. The raw Keychain calls are isolated behind
/// `KeychainBackend` so the store's logic is testable without a live Keychain.
public final class KeychainCacheStore: SecureCacheStore {
    private let backend: KeychainBackend
    private let logger: Logger?

    /// Production initialiser — talks to the real system Keychain.
    public convenience init(service: String = "com.core.securecache", logger: Logger? = nil) {
        self.init(backend: SystemKeychainBackend(service: service), logger: logger)
    }

    /// Seam initialiser — inject a fake `KeychainBackend` in tests.
    init(backend: KeychainBackend, logger: Logger? = nil) {
        self.backend = backend
        self.logger = logger
    }

    public func get<T: Codable>(_: T.Type, key: String) -> T? {
        guard let data = backend.read(key: key) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger?.error(
                "[KeychainCacheStore] decode failed for key '\(key)': \(error)",
                file: #file,
                function: #function,
                line: #line
            )
            return nil
        }
    }

    public func set(_ value: some Codable, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            backend.write(data, key: key)
        } catch {
            logger?.error(
                "[KeychainCacheStore] encode failed for key '\(key)': \(error)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }

    public func remove(key: String) {
        backend.delete(key: key)
    }

    public func clearAll() {
        backend.deleteAll()
    }
}

/// The narrow raw-bytes Keychain surface `KeychainCacheStore` needs. Internal —
/// an implementation detail / test seam, not part of `Core`'s public API.
protocol KeychainBackend {
    func read(key: String) -> Data?
    func write(_ data: Data, key: String)
    func delete(key: String)
    func deleteAll()
}
