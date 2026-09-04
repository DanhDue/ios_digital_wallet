/// User intents the `{{name.pascalCase()}}` screen can receive (Source Spec §5.4).
///
/// See: Features/Settings/Sources/Settings/Presentation/SettingsAction.swift
public enum {{name.pascalCase()}}Action: Equatable {
    /// The screen appeared — (re)load the persisted value.
    case onAppear
    /// Edit the title (optimistic, then persisted). An empty string is ignored.
    case titleChanged(String)
    /// Bump the counter (optimistic, then persisted).
    case increment
}
