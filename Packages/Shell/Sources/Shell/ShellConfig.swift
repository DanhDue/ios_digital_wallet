/// Static tab-layout configuration handed to the ``ShellViewModel`` by the `App`
/// composition root (Source Spec §4.1). The Shell never hard-codes tab counts.
public struct ShellConfig: Equatable {
    /// Number of tabs the shell manages.
    public let tabCount: Int

    /// Tab selected on a cold start. The template defaults to `2` (Settings) so
    /// a fresh clone shows a real MVI feature immediately — matching the Flutter
    /// and Android templates.
    public let initialTab: Int

    public init(tabCount: Int = 3, initialTab: Int = 2) {
        self.tabCount = tabCount
        self.initialTab = initialTab
    }
}
