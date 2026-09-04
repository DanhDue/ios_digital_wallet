/// The Settings screen's single observable state (Source Spec §5.4).
public struct SettingsState: Equatable {
    /// The settings currently shown / edited. Mutated optimistically before the
    /// persist round-trip completes.
    public var settings: SettingsEntity
    /// `true` while a persist effect is in flight.
    public var isSaving: Bool

    public init(settings: SettingsEntity, isSaving: Bool = false) {
        self.settings = settings
        self.isSaving = isSaving
    }
}
