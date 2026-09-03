import Core

/// The single reader / writer of the `"{{name.camelCase()}}"` cache slot
/// (Source Spec §4.4).
///
/// `Core.CacheStore` collapses a missing key **and** a decode failure to `nil`
/// (and logs the decode failure at `.error`), so this type never branches on
/// "missing vs corrupt" — it just forwards. `internal` (ArchTests K4).
///
/// See: Packages/Features/SettingsFeature/Sources/SettingsFeature/Data/Local/SettingsLocalDataSource.swift
struct {{name.pascalCase()}}LocalDataSource {
    /// The cache key the whole feature agrees on.
    static let storageKey = "{{name.camelCase()}}"

    private let cache: any CacheStore

    init(cache: any CacheStore) {
        self.cache = cache
    }

    /// The stored DTO, or `nil` when absent or unreadable.
    func read() -> {{name.pascalCase()}}DTO? {
        cache.get({{name.pascalCase()}}DTO.self, key: Self.storageKey)
    }

    func write(_ dto: {{name.pascalCase()}}DTO) {
        cache.set(dto, key: Self.storageKey)
    }

    func clear() {
        cache.remove(key: Self.storageKey)
    }
}
