/// One-shot effects the shell emits on its `eventSubject` (Source Spec §5.4).
public enum ShellEvent: Equatable {
    /// Sent when the user re-taps the already-active tab. The tab's root screen
    /// observes this to scroll its content back to the top.
    case scrollToTop(tab: Int)
}
