#if DEBUG
    import D3NexusLogging
    import Foundation
    import Pulse

    /// Developer-facing Pulse appender mapping `LogRecord` into `Pulse.LoggerStore`.
    ///
    /// Sets `respectsModuleToggle = true` so muting a noisy module cleans up the in-app
    /// console without altering system telemetry (`OSLogAppender`).
    public final class PulseAppender: LogAppender, @unchecked Sendable {
        public let id: String = "pulse"
        public let respectsModuleToggle: Bool = true
        private let store: LoggerStore

        public init(store: LoggerStore = .shared) {
            self.store = store
        }

        public func append(_ record: LogRecord) {
            let pulseLevel: LoggerStore.Level = switch record.level {
            case .verbose:
                .trace
            case .debug:
                .debug
            case .info:
                .info
            case .warning:
                .warning
            case .error:
                .error
            }

            var metadata: [String: LoggerStore.MetadataValue] = [:]
            for (key, value) in record.metadata {
                metadata[key] = .string(value)
            }
            metadata["traceId"] = .string(record.traceId)
            metadata["spanId"] = .string(record.spanId)
            if let parent = record.parentSpanId {
                metadata["parentSpanId"] = .string(parent)
            }

            store.storeMessage(
                createdAt: record.timestamp,
                label: record.module,
                level: pulseLevel,
                message: record.message,
                metadata: metadata
            )
        }
    }
#endif
