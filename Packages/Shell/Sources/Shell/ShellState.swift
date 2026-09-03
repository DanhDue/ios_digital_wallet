/// The shell's single observable state (Source Spec §5.4): which tab is visible.
public struct ShellState: Equatable {
    /// Index of the currently-selected tab.
    public var selectedTab: Int

    public init(selectedTab: Int) {
        self.selectedTab = selectedTab
    }
}
