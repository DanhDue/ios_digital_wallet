/// User intents the Settings screen can receive (Source Spec §5.4).
public enum SettingsAction: Equatable {
    /// The screen appeared — (re)load the persisted settings.
    case onAppear
    /// Flip the dark-mode preference (optimistic, then persisted).
    case toggleDarkMode
    /// Choose `language`. An empty string is ignored.
    case selectLanguage(String)
    /// Show or dismiss the language picker modal bottom sheet.
    case showLanguagePicker(Bool)
    /// Toggle developer mode card section visibility.
    case toggleDeveloperMode(Bool)
    /// Flip the notifications preference (optimistic, then persisted).
    case toggleNotifications
}
