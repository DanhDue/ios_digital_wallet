#if DEBUG
    import Foundation

    /// Cancellable registration token returned by `LeakSentinelClock`.
    public protocol LeakSentinelCancellable: Sendable {
        func cancel()
    }

    /// Injectable clock abstraction allowing deterministic, zero-sleep testing of `LeakSentinel`.
    public protocol LeakSentinelClock: Sendable {
        @discardableResult
        func schedule(
            after delay: TimeInterval,
            action: @escaping @Sendable () -> Void
        ) -> any LeakSentinelCancellable
    }

    /// System clock implementation using `DispatchQueue.main.asyncAfter`.
    public final class SystemLeakSentinelClock: LeakSentinelClock, @unchecked Sendable {
        public init() {}

        private final class Token: LeakSentinelCancellable, @unchecked Sendable {
            private var isCancelled = false
            private let lock = NSLock()

            func cancel() {
                lock.lock()
                defer { lock.unlock() }
                isCancelled = true
            }

            func execute(action: @escaping @Sendable () -> Void) {
                lock.lock()
                let cancelled = isCancelled
                lock.unlock()
                if !cancelled {
                    action()
                }
            }
        }

        @discardableResult
        public func schedule(
            after delay: TimeInterval,
            action: @escaping @Sendable () -> Void
        ) -> any LeakSentinelCancellable {
            let token = Token()
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                token.execute(action: action)
            }
            return token
        }
    }
#endif
