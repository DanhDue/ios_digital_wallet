/// User intents the `Result` sub-screen can receive (Source Spec §5.4). The
/// screen only ever needs to announce that it appeared — the code it shows
/// arrives already resolved, at construction time, from
/// `ScannerResultRoute.code`.
///
/// See: Features/Settings/Sources/Settings/Presentation/SettingsAction.swift
public enum ResultAction: Equatable {
    /// The sub-screen appeared.
    case onAppear
}
