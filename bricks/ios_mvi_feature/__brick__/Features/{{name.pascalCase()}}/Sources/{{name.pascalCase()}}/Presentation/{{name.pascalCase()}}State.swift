/// The `{{name.pascalCase()}}` screen's single observable state (Source Spec §5.4).
///
/// See: Features/Settings/Sources/Settings/Presentation/SettingsState.swift
public struct {{name.pascalCase()}}State: Equatable {
    /// The value currently shown / edited. Mutated optimistically before the
    /// persist round-trip completes.
    public var entity: {{name.pascalCase()}}Entity
    /// `true` while a persist effect is in flight.
    public var isSaving: Bool

    public init(entity: {{name.pascalCase()}}Entity, isSaving: Bool = false) {
        self.entity = entity
        self.isSaving = isSaving
    }
}
