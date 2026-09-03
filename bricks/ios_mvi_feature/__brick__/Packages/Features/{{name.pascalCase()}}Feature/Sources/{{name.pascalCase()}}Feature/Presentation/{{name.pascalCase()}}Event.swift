/// One-shot effects the `{{name.pascalCase()}}` screen emits on its
/// `eventSubject` (Source Spec §5.4).
///
/// See: Packages/Features/SettingsFeature/Sources/SettingsFeature/Presentation/SettingsEvent.swift
public enum {{name.pascalCase()}}Event: Equatable {
    /// A persist attempt failed; the optimistic change has already been rolled
    /// back. Carries the user-facing failure message.
    case saveFailed(String)
}
