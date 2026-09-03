/// User intents the `{{name.pascalCase()}}` sub-screen can receive
/// (Source Spec §5.4).
///
/// See: Packages/Features/SettingsFeature/Sources/SettingsFeature/Presentation/SettingsAction.swift
public enum {{name.pascalCase()}}Action: Equatable {
    /// The sub-screen appeared.
    case onAppear
    /// Bump the local counter.
    case increment
}
