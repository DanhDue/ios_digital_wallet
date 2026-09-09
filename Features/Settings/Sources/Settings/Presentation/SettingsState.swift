/// The Settings screen's single observable state (Source Spec §5.4).
public struct SettingsState: Equatable {
    /// The settings currently shown / edited. Mutated optimistically before the
    /// persist round-trip completes.
    public var settings: SettingsEntity
    /// `true` while first-time loading without cache is in flight.
    public var isLoading: Bool
    /// `true` while a persist effect is in flight.
    public var isSaving: Bool
    /// `true` while remote translations are being fetched for an uncached language.
    public var isLoadingLanguage: Bool
    /// Controls presentation of the language picker modal bottom sheet.
    public var isLanguagePickerPresented: Bool
    /// Controls visibility of developer options.
    public var isDeveloperModeEnabled: Bool
    /// App version string displayed in the UI.
    public var appVersion: String
    /// App build number displayed in the UI.
    public var buildNumber: String

    public init(
        settings: SettingsEntity = .default,
        isLoading: Bool = false,
        isSaving: Bool = false,
        isLoadingLanguage: Bool = false,
        isLanguagePickerPresented: Bool = false,
        isDeveloperModeEnabled: Bool = false,
        appVersion: String = "1.0.0",
        buildNumber: String = "1"
    ) {
        self.settings = settings
        self.isLoading = isLoading
        self.isSaving = isSaving
        self.isLoadingLanguage = isLoadingLanguage
        self.isLanguagePickerPresented = isLanguagePickerPresented
        self.isDeveloperModeEnabled = isDeveloperModeEnabled
        self.appVersion = appVersion
        self.buildNumber = buildNumber
    }
}
