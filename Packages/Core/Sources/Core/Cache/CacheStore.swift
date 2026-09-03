import Foundation

/// A typed key/value cache for `Codable` values. Reads never throw — a missing
/// key or a decode failure is `nil`.
public protocol CacheStore {
    func get<T: Codable>(_ type: T.Type, key: String) -> T?
    func set(_ value: some Codable, key: String)
    func remove(key: String)
    func clearAll()
}

/// `UserDefaults`-backed `CacheStore`. Values are JSON-encoded; keys are
/// namespaced with `keyPrefix` so `clearAll()` only wipes this store's entries.
public final class UserDefaultsCacheStore: CacheStore {
    private let defaults: UserDefaults
    private let keyPrefix: String
    private let logger: Logger?

    public init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "core.cache.",
        logger: Logger? = nil
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        self.logger = logger
    }

    public func get<T: Codable>(_: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: keyPrefix + key) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger?.error(
                "[UserDefaultsCacheStore] decode failed for key '\(key)': \(error)",
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
            defaults.set(data, forKey: keyPrefix + key)
        } catch {
            logger?.error(
                "[UserDefaultsCacheStore] encode failed for key '\(key)': \(error)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }

    public func remove(key: String) {
        defaults.removeObject(forKey: keyPrefix + key)
    }

    public func clearAll() {
        let staleKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(keyPrefix) }
        for key in staleKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
