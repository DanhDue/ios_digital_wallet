#if DEBUG
    import Foundation

    /// Cancellable registration token returned by `LeakSentinel.track(...)`.
    public final class LeakSentinelToken: Sendable {
        private let cancellable: any LeakSentinelCancellable

        public init(cancellable: any LeakSentinelCancellable) {
            self.cancellable = cancellable
        }

        public func cancel() {
            cancellable.cancel()
        }
    }

    private final class WeakReference: @unchecked Sendable {
        private(set) weak var value: AnyObject?

        init(_ value: AnyObject) {
            self.value = value
        }

        var isAlive: Bool {
            value != nil
        }
    }

    /// Opt-in, DEBUG-only runtime deallocation checker.
    ///
    /// Registers an object with an expected end-of-life; after a grace period the sentinel
    /// checks a weak reference and, if the object is still alive, emits a `LogRecord` at
    /// `.error` level through `LogManager`.
    public final class LeakSentinel: @unchecked Sendable {
        public static let shared = LeakSentinel()

        private let clock: any LeakSentinelClock
        private let logManager: (any LogManager)?
        private let logManagerProvider: (@Sendable () -> (any LogManager)?)?

        public init(
            clock: any LeakSentinelClock = SystemLeakSentinelClock(),
            logManager: (any LogManager)? = nil,
            logManagerProvider: (@Sendable () -> (any LogManager)?)? = nil
        ) {
            self.clock = clock
            self.logManager = logManager
            self.logManagerProvider = logManagerProvider
        }

        private func resolvedLogManager() -> (any LogManager)? {
            if let logManager {
                return logManager
            }
            if let logManagerProvider {
                return logManagerProvider()
            }
            return D3NexusLogger.activeManager
        }

        /// Tracks an object for unexpected retention beyond a specified grace period.
        ///
        /// - Parameters:
        ///   - object: The object expected to deallocate. Held weakly.
        ///   - name: Descriptive identifier for diagnostic logs.
        ///   - gracePeriod: Time interval in seconds before verifying deallocation.
        /// - Returns: A token allowing cancellation if the object is re-presented or legitimately retained.
        @discardableResult
        public func track(
            _ object: AnyObject,
            name: String,
            gracePeriod: TimeInterval = 3.0
        ) -> LeakSentinelToken {
            let reference = WeakReference(object)
            let cancellable = clock.schedule(after: gracePeriod) { [weak self] in
                guard let self else { return }
                if reference.isAlive {
                    let manager = resolvedLogManager()
                    let record = LogRecord(
                        module: "LeakSentinel",
                        level: .error,
                        message: "Potential memory leak detected: \(name) outlived grace period of \(gracePeriod)s",
                        traceId: TraceIdentifier.newTraceId(),
                        spanId: TraceIdentifier.newSpanId(),
                        metadata: [
                            "leakedObject": name,
                            "gracePeriod": "\(gracePeriod)",
                        ]
                    )
                    manager?.log(record)
                }
            }
            return LeakSentinelToken(cancellable: cancellable)
        }
    }
#endif
