import Foundation

/// Concrete implementation of `LoggerProtocol`.
///
/// Spawns child loggers with value-type span linkage, preventing retain cycles.
public final class LoggerImpl: LoggerProtocol, @unchecked Sendable {
    public let module: String
    public let traceId: String
    public let spanId: String
    public let parentSpanId: String?
    private let manager: any LogManager

    public init(
        module: String,
        traceId: String,
        spanId: String,
        parentSpanId: String? = nil,
        manager: any LogManager
    ) {
        self.module = module
        self.traceId = traceId
        self.spanId = spanId
        self.parentSpanId = parentSpanId
        self.manager = manager
    }

    public func verbose(_ message: String, error: (any Error)?, metadata: [String: String]?) {
        emit(level: .verbose, message: message, error: error, metadata: metadata)
    }

    public func debug(_ message: String, error: (any Error)?, metadata: [String: String]?) {
        emit(level: .debug, message: message, error: error, metadata: metadata)
    }

    public func info(_ message: String, error: (any Error)?, metadata: [String: String]?) {
        emit(level: .info, message: message, error: error, metadata: metadata)
    }

    public func warning(_ message: String, error: (any Error)?, metadata: [String: String]?) {
        emit(level: .warning, message: message, error: error, metadata: metadata)
    }

    public func error(_ message: String, error: (any Error)?, metadata: [String: String]?) {
        emit(level: .error, message: message, error: error, metadata: metadata)
    }

    public func withSpan() -> any LoggerProtocol {
        LoggerImpl(
            module: module,
            traceId: traceId,
            spanId: TraceIdentifier.newSpanId(),
            parentSpanId: spanId,
            manager: manager
        )
    }

    private func emit(
        level: LogLevel,
        message: String,
        error: (any Error)?,
        metadata: [String: String]?
    ) {
        let record = LogRecord(
            module: module,
            level: level,
            message: message,
            timestamp: Date(),
            traceId: traceId,
            spanId: spanId,
            parentSpanId: parentSpanId,
            errorDescription: error.map { String(describing: $0) },
            metadata: metadata ?? [:]
        )
        manager.log(record)
    }
}
