#if DEBUG
    import Foundation

    public enum LeakDemoEvent: Equatable, Sendable {
        case leakTriggered
        case cleanTriggered
    }
#endif
