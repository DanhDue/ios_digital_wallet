/// A momentary, broadcast notification with no reply.
///
/// Delivered through ``AppEventBus`` with **replay 0** — a subscriber that was
/// not listening when an event was published simply waits for the next one.
///
/// `Sendable`: events are published from OS-triggered callbacks on arbitrary
/// threads (network interceptor, lifecycle observer), so a value must be safe to
/// hand to subscribers on another thread. This refines the spec's bare
/// `protocol AppEvent {}` and is forced by Swift 6 strict concurrency; every
/// concrete event below is a trivial value type.
public protocol AppEvent: Sendable {}

/// The shell changed which tab is visible.
public struct ShellTabVisibilityChanged: AppEvent {
    public let tabIndex: Int
    public let isVisible: Bool

    public init(tabIndex: Int, isVisible: Bool) {
        self.tabIndex = tabIndex
        self.isVisible = isVisible
    }
}

/// The app moved between scene phases.
public struct AppLifecycleChanged: AppEvent {
    public enum State: Sendable {
        case foreground
        case background
        case inactive
    }

    public let state: State

    public init(state: State) {
        self.state = state
    }
}

/// The session ended (e.g. a 401 surfaced through `Core.AuthEventSink`).
public struct UserLoggedOut: AppEvent {
    public init() {}
}
