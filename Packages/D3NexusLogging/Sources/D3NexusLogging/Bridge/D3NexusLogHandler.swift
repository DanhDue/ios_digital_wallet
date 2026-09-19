import Foundation
import Logging

/// Bridge translating `swift-log` (`apple/swift-log`) events into `LogRecord` instances dispatched via `LogManager`.
///
/// Level Mapping:
/// - `.trace`    → `LogLevel.verbose`
/// - `.debug`    → `LogLevel.debug`
/// - `.info`     → `LogLevel.info`
/// - `.notice`   → `LogLevel.info`
/// - `.warning`  → `LogLevel.warning`
/// - `.error`    → `LogLevel.error`
/// - `.critical` → `LogLevel.error` (lossy collapse onto `.error`)
public struct D3NexusLogHandler: LogHandler, Sendable {
    public var metadata: Logging.Logger.Metadata = [:]
    public var logLevel: Logging.Logger.Level = .info

    private let label: String
    private let manager: any LogManager

    /// Initializes a log handler for swift-log interoperability.
    ///
    /// - Parameters:
    ///   - label: The logger label, translated to `LogRecord.module`.
    ///   - manager: The central `LogManager` dispatching received records.
    public init(label: String, manager: any LogManager) {
        self.label = label
        self.manager = manager
    }

    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    // swiftlint:disable:next function_parameter_count
    public func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        source _: String,
        file _: String,
        function _: String,
        line _: UInt
    ) {
        var mergedMetadata = self.metadata
        if let metadata {
            mergedMetadata.merge(metadata) { _, new in new }
        }

        let traceId = mergedMetadata["traceId"]?.description ?? TraceIdentifier.newTraceId()
        let spanId = mergedMetadata["spanId"]?.description ?? TraceIdentifier.newSpanId()
        let parentSpanId = mergedMetadata["parentSpanId"]?.description

        var stringifiedMetadata: [String: String] = [:]
        for (key, value) in mergedMetadata {
            stringifiedMetadata[key] = value.description
        }

        let record = LogRecord(
            module: label,
            level: mapLevel(level),
            message: message.description,
            traceId: traceId,
            spanId: spanId,
            parentSpanId: parentSpanId,
            metadata: stringifiedMetadata
        )

        manager.log(record)
    }

    public func log(event: Logging.LogEvent) {
        log(
            level: event.level,
            message: event.message,
            metadata: event.metadata,
            source: event.source,
            file: event.file,
            function: event.function,
            line: event.line
        )
    }

    private func mapLevel(_ level: Logging.Logger.Level) -> LogLevel {
        switch level {
        case .trace:
            .verbose
        case .debug:
            .debug
        case .info, .notice:
            .info
        case .warning:
            .warning
        case .error, .critical:
            .error
        }
    }
}
