/// The on-disk shape of the settings, JSON-encoded into `Core.CacheStore` under
/// the `"settings"` key. Deliberately separate from `SettingsEntity` so a
/// storage-format change never ripples into the Domain (Source Spec §4.4).
///
/// `internal` — the whole `Data` layer is reached only through
/// `SettingsRepository` (ArchTests K4).
struct SettingsDTO: Codable, Equatable {
    let isDarkMode: Bool
    let language: String
    let notificationsEnabled: Bool
}
