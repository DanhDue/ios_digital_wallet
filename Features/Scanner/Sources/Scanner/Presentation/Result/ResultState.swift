/// The `Result` sub-screen's single observable state (Source Spec §5.4).
///
/// See: Features/Settings/Sources/Settings/Presentation/SettingsState.swift
public struct ResultState: Equatable {
    /// The code the Scanner screen just decoded, carried in by
    /// `ScannerResultRoute.code`. Set once at construction and never mutated
    /// afterward — the screen only displays it, it never parses or validates
    /// it (Source Spec §4.11 keeps the template domain-neutral).
    public var code: String

    public init(code: String) {
        self.code = code
    }
}
