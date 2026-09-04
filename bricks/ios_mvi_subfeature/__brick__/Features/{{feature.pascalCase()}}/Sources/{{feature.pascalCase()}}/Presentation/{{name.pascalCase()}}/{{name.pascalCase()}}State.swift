/// The `{{name.pascalCase()}}` sub-screen's single observable state
/// (Source Spec §5.4).
///
/// See: Features/Settings/Sources/Settings/Presentation/SettingsState.swift
public struct {{name.pascalCase()}}State: Equatable {
    /// A local counter — replace with the sub-screen's real state.
    public var count: Int

    public init(count: Int = 0) {
        self.count = count
    }
}
