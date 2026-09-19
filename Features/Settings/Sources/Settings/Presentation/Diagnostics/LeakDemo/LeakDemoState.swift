#if DEBUG
    import Foundation

    public struct LeakDemoState: Equatable, Sendable {
        public var statusMessage: String
        public var isLeakingTriggered: Bool
        public var isCleanTriggered: Bool

        public init(
            statusMessage: String = "Idle",
            isLeakingTriggered: Bool = false,
            isCleanTriggered: Bool = false
        ) {
            self.statusMessage = statusMessage
            self.isLeakingTriggered = isLeakingTriggered
            self.isCleanTriggered = isCleanTriggered
        }
    }
#endif
