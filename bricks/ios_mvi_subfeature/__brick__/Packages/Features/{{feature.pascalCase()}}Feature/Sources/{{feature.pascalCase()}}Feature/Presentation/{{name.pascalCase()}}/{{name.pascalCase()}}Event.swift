/// One-shot effects the `{{name.pascalCase()}}` sub-screen emits on its
/// `eventSubject` (Source Spec §5.4).
///
/// See: Packages/Features/SettingsFeature/Sources/SettingsFeature/Presentation/SettingsEvent.swift
public enum {{name.pascalCase()}}Event: Equatable {
    /// The counter reached a multiple of five.
    case milestone(Int)
}
