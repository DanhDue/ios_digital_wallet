/// User intents the shell can receive (Source Spec §5.4).
public enum ShellAction: Equatable {
    /// The user asked for tab `index`. A value outside `0..<tabCount` is ignored;
    /// re-selecting the active tab pops that tab's stack to root and emits
    /// ``ShellEvent/scrollToTop(tab:)``.
    case selectTab(Int)
}
