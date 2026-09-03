/// The user-facing preferences the Settings screen edits (Source Spec §4.4).
///
/// Pure value type — no framework imports (ArchTests K3). Mutated in place by the
/// ViewModel's optimistic reducers, then handed to `SaveSettingsUseCase`.
public struct SettingsEntity: Equatable, Sendable {
    /// Whether the app renders in its dark colour scheme.
    public var isDarkMode: Bool
    /// BCP-47-ish language tag the UI is presented in (e.g. `"en"`, `"vi"`).
    public var language: String
    /// Whether local / push notifications are enabled.
    public var notificationsEnabled: Bool

    public init(isDarkMode: Bool, language: String, notificationsEnabled: Bool) {
        self.isDarkMode = isDarkMode
        self.language = language
        self.notificationsEnabled = notificationsEnabled
    }

    /// The entity a fresh install (or an unreadable cache) starts from.
    public static let `default` = SettingsEntity(
        isDarkMode: false,
        language: "en",
        notificationsEnabled: true
    )
}
