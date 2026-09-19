#if DEBUG
    import Foundation

    public enum LeakDemoAction: Sendable {
        case triggerLeak
        case triggerClean
        case onAppear
        case onDisappear
    }
#endif
