import Core

/// The single reader / writer of the `"settings"` cache slot (Source Spec §4.4).
///
/// `Core.CacheStore` already collapses a missing key **and** a decode failure to
/// `nil` (and, in `UserDefaultsCacheStore`, logs the decode failure at `.error`),
/// so this type never has to branch on "missing vs corrupt" — it just forwards.
/// `internal` (ArchTests K4).
struct SettingsLocalDataSource {
    /// The cache key the whole feature agrees on.
    static let storageKey = "settings"

    private let cache: any CacheStore

    init(cache: any CacheStore) {
        self.cache = cache
    }

    /// The stored DTO, or `nil` when absent or unreadable.
    func read() -> SettingsDTO? {
        cache.get(SettingsDTO.self, key: Self.storageKey)
    }

    func write(_ dto: SettingsDTO) {
        cache.set(dto, key: Self.storageKey)
    }

    func clear() {
        cache.remove(key: Self.storageKey)
    }
}
